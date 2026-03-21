"""FastAPI Smart Assistant endpoint for SmartSaving (Gemini + PostgreSQL)."""

from __future__ import annotations

import os
import re
from dataclasses import dataclass
from functools import lru_cache
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel, Field

try:
    import google.generativeai as genai
except ImportError:  # pragma: no cover - handled with runtime config error
    genai = None  # type: ignore[assignment]

try:
    from psycopg import AsyncConnection, sql
    from psycopg.rows import dict_row
except ImportError:  # pragma: no cover - handled with runtime config error
    AsyncConnection = None  # type: ignore[assignment]
    dict_row = None  # type: ignore[assignment]
    sql = None  # type: ignore[assignment]

router = APIRouter(tags=["assistant"])

SYSTEM_PROMPT = """You are SmartSaving Assistant, an AI that helps users decide when to buy products.

Rules:

* If predicted price is lower than current price -> recommend WAIT
* If predicted price is higher -> recommend BUY NOW
* Keep answers short and clear
* Explain reasoning in simple language."""

_IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, max_length=2000)
    product_id: int = Field(..., gt=0)


class ChatResponse(BaseModel):
    reply: str


@dataclass(frozen=True)
class PricePoint:
    timestamp: str
    price: float


@dataclass(frozen=True)
class ProductSnapshot:
    product_id: int
    name: str
    current_price: float
    predicted_price: Optional[float]
    price_trend: str
    price_history: list[PricePoint]


@dataclass(frozen=True)
class DatabaseSettings:
    dsn: str
    product_table: str
    product_id_column: str
    product_name_column: str
    current_price_column: str
    prediction_table: str
    prediction_product_id_column: str
    predicted_price_column: str
    prediction_created_at_column: str
    history_table: str
    history_product_id_column: str
    history_price_column: str
    history_timestamp_column: str
    history_limit: int


@dataclass(frozen=True)
class GeminiSettings:
    api_key: str
    model: str


@dataclass(frozen=True)
class AppSettings:
    database: DatabaseSettings
    gemini: GeminiSettings


class ConfigError(RuntimeError):
    """Raised when required runtime configuration is missing."""


class ProductDataAccessError(RuntimeError):
    """Raised when product data cannot be read from PostgreSQL."""


class GeminiServiceError(RuntimeError):
    """Raised when Gemini generation fails."""


def _required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ConfigError(f"{name} is not configured.")
    return value


def _identifier_env(name: str, default: str) -> str:
    value = os.getenv(name, default).strip()
    if not _IDENTIFIER_PATTERN.fullmatch(value):
        raise ConfigError(
            f"{name} has invalid SQL identifier value '{value}'. "
            "Use only letters, numbers, and underscores."
        )
    return value


def _positive_int_env(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None:
        return default
    try:
        value = int(raw)
    except ValueError as exc:
        raise ConfigError(f"{name} must be an integer.") from exc
    if value <= 0:
        raise ConfigError(f"{name} must be greater than 0.")
    return value


@lru_cache
def get_settings() -> AppSettings:
    if genai is None:
        raise ConfigError("google-generativeai is not installed.")
    if AsyncConnection is None or dict_row is None or sql is None:
        raise ConfigError("psycopg is not installed.")

    database = DatabaseSettings(
        dsn=_required_env("DATABASE_URL"),
        product_table=_identifier_env("DB_PRODUCT_TABLE", "products"),
        product_id_column=_identifier_env("DB_PRODUCT_ID_COLUMN", "id"),
        product_name_column=_identifier_env("DB_PRODUCT_NAME_COLUMN", "name"),
        current_price_column=_identifier_env(
            "DB_CURRENT_PRICE_COLUMN", "current_price"
        ),
        prediction_table=_identifier_env("DB_PREDICTION_TABLE", "price_predictions"),
        prediction_product_id_column=_identifier_env(
            "DB_PREDICTION_PRODUCT_ID_COLUMN", "product_id"
        ),
        predicted_price_column=_identifier_env(
            "DB_PREDICTED_PRICE_COLUMN", "predicted_price"
        ),
        prediction_created_at_column=_identifier_env(
            "DB_PREDICTION_CREATED_AT_COLUMN", "created_at"
        ),
        history_table=_identifier_env("DB_HISTORY_TABLE", "price_history"),
        history_product_id_column=_identifier_env(
            "DB_HISTORY_PRODUCT_ID_COLUMN", "product_id"
        ),
        history_price_column=_identifier_env("DB_HISTORY_PRICE_COLUMN", "price"),
        history_timestamp_column=_identifier_env(
            "DB_HISTORY_TIMESTAMP_COLUMN", "recorded_at"
        ),
        history_limit=_positive_int_env("DB_HISTORY_LIMIT", 30),
    )
    gemini = GeminiSettings(
        api_key=_required_env("GEMINI_API_KEY"),
        model=os.getenv("GEMINI_MODEL", "gemini-1.5-flash").strip()
        or "gemini-1.5-flash",
    )
    return AppSettings(database=database, gemini=gemini)


def get_app_settings() -> AppSettings:
    try:
        return get_settings()
    except ConfigError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


class ProductRepository:
    def __init__(self, settings: DatabaseSettings) -> None:
        self._settings = settings

    async def get_product_snapshot(self, product_id: int) -> Optional[ProductSnapshot]:
        try:
            async with await AsyncConnection.connect(self._settings.dsn) as conn:
                async with conn.cursor(row_factory=dict_row) as cursor:
                    product_row = await self._fetch_product_row(cursor, product_id)
                    if product_row is None:
                        return None

                    predicted_price = await self._fetch_predicted_price(cursor, product_id)
                    history = await self._fetch_price_history(cursor, product_id)
                    trend = _derive_trend(history)

                    return ProductSnapshot(
                        product_id=product_id,
                        name=str(product_row["product_name"]),
                        current_price=_to_float(
                            product_row["current_price"], "current_price"
                        ),
                        predicted_price=predicted_price,
                        price_trend=trend,
                        price_history=history,
                    )
        except ProductDataAccessError:
            raise
        except Exception as exc:  # pragma: no cover - driver level errors
            raise ProductDataAccessError(str(exc)) from exc

    async def _fetch_product_row(self, cursor: Any, product_id: int) -> Optional[dict]:
        query = sql.SQL(
            """
            SELECT
                {product_name} AS product_name,
                {current_price} AS current_price
            FROM {products}
            WHERE {product_id} = %s
            """
        ).format(
            product_name=sql.Identifier(self._settings.product_name_column),
            current_price=sql.Identifier(self._settings.current_price_column),
            products=sql.Identifier(self._settings.product_table),
            product_id=sql.Identifier(self._settings.product_id_column),
        )
        await cursor.execute(query, (product_id,))
        return await cursor.fetchone()

    async def _fetch_predicted_price(self, cursor: Any, product_id: int) -> Optional[float]:
        ordered_query = sql.SQL(
            """
            SELECT {predicted_price} AS predicted_price
            FROM {predictions}
            WHERE {prediction_product_id} = %s
            ORDER BY {created_at} DESC NULLS LAST
            LIMIT 1
            """
        ).format(
            predicted_price=sql.Identifier(self._settings.predicted_price_column),
            predictions=sql.Identifier(self._settings.prediction_table),
            prediction_product_id=sql.Identifier(
                self._settings.prediction_product_id_column
            ),
            created_at=sql.Identifier(self._settings.prediction_created_at_column),
        )
        fallback_query = sql.SQL(
            """
            SELECT {predicted_price} AS predicted_price
            FROM {predictions}
            WHERE {prediction_product_id} = %s
            LIMIT 1
            """
        ).format(
            predicted_price=sql.Identifier(self._settings.predicted_price_column),
            predictions=sql.Identifier(self._settings.prediction_table),
            prediction_product_id=sql.Identifier(
                self._settings.prediction_product_id_column
            ),
        )

        row = None
        try:
            await cursor.execute(ordered_query, (product_id,))
            row = await cursor.fetchone()
        except Exception:
            try:
                await cursor.execute(fallback_query, (product_id,))
                row = await cursor.fetchone()
            except Exception as exc:
                raise ProductDataAccessError("Failed to fetch predicted price.") from exc

        if row is None:
            return None
        return _to_optional_float(row.get("predicted_price"), "predicted_price")

    async def _fetch_price_history(self, cursor: Any, product_id: int) -> list[PricePoint]:
        query = sql.SQL(
            """
            SELECT
                {history_timestamp} AS history_timestamp,
                {history_price} AS history_price
            FROM {history}
            WHERE {history_product_id} = %s
            ORDER BY {history_timestamp} ASC
            LIMIT %s
            """
        ).format(
            history_timestamp=sql.Identifier(self._settings.history_timestamp_column),
            history_price=sql.Identifier(self._settings.history_price_column),
            history=sql.Identifier(self._settings.history_table),
            history_product_id=sql.Identifier(self._settings.history_product_id_column),
        )
        try:
            await cursor.execute(query, (product_id, self._settings.history_limit))
            rows = await cursor.fetchall()
        except Exception as exc:
            raise ProductDataAccessError("Failed to fetch price history.") from exc

        points: list[PricePoint] = []
        for row in rows:
            points.append(
                PricePoint(
                    timestamp=_to_timestamp_string(row["history_timestamp"]),
                    price=_to_float(row["history_price"], "history_price"),
                )
            )
        return points


def get_product_repository(
    settings: AppSettings = Depends(get_app_settings),
) -> ProductRepository:
    return ProductRepository(settings.database)


def _to_float(value: Any, field_name: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise ProductDataAccessError(
            f"Invalid numeric value for '{field_name}'."
        ) from exc


def _to_optional_float(value: Any, field_name: str) -> Optional[float]:
    if value is None:
        return None
    return _to_float(value, field_name)


def _to_timestamp_string(value: Any) -> str:
    if hasattr(value, "isoformat"):
        return str(value.isoformat())
    return str(value)


def _derive_trend(history: list[PricePoint]) -> str:
    if len(history) < 2:
        return "stable"

    first_price = history[0].price
    last_price = history[-1].price
    if first_price <= 0:
        return "stable"

    change_ratio = (last_price - first_price) / first_price
    if change_ratio > 0.01:
        return "increasing"
    if change_ratio < -0.01:
        return "decreasing"
    return "stable"


def _build_prompt(snapshot: ProductSnapshot, user_message: str) -> str:
    predicted_price = (
        f"{snapshot.predicted_price:.2f}"
        if snapshot.predicted_price is not None
        else "Unknown"
    )
    history_lines = (
        "\n".join(
            f"- {point.timestamp}: {point.price:.2f}"
            for point in reversed(snapshot.price_history[-14:])
        )
        if snapshot.price_history
        else "- No history available"
    )

    return (
        f"Product: {snapshot.name}\n"
        f"Current price: {snapshot.current_price:.2f}\n"
        f"Predicted price: {predicted_price}\n"
        f"Price trend: {snapshot.price_trend}\n"
        "Price history (latest first, up to 14 points):\n"
        f"{history_lines}\n\n"
        f"User message: {user_message}\n\n"
        "Output format:\n"
        "1) Recommendation: BUY NOW or WAIT\n"
        "2) Reasoning: 2-4 short sentences in simple language.\n"
        "If predicted price is unknown, acknowledge it and use available trend/history."
    )


class GeminiAssistant:
    def __init__(self, settings: GeminiSettings) -> None:
        self._settings = settings
        genai.configure(api_key=settings.api_key)
        self._model = genai.GenerativeModel(
            model_name=settings.model,
            system_instruction=SYSTEM_PROMPT,
        )

    def generate_reply(self, prompt: str) -> str:
        try:
            response = self._model.generate_content(
                prompt,
                generation_config=genai.types.GenerationConfig(
                    temperature=0.2,
                    max_output_tokens=240,
                ),
            )
        except Exception as exc:
            raise GeminiServiceError(f"Gemini API call failed: {exc}") from exc

        text = (getattr(response, "text", None) or "").strip()
        if text:
            return text

        text = self._extract_text_from_candidates(response)
        if text:
            return text

        raise GeminiServiceError("Gemini returned an empty response.")

    @staticmethod
    def _extract_text_from_candidates(response: Any) -> str:
        candidates = getattr(response, "candidates", None) or []
        for candidate in candidates:
            content = getattr(candidate, "content", None)
            if content is None:
                continue
            parts = getattr(content, "parts", None) or []
            texts = []
            for part in parts:
                value = getattr(part, "text", None)
                if value:
                    texts.append(str(value))
            if texts:
                return "\n".join(texts).strip()
        return ""


@lru_cache
def _get_gemini_assistant_cached() -> GeminiAssistant:
    settings = get_settings()
    return GeminiAssistant(settings.gemini)


def get_gemini_assistant() -> GeminiAssistant:
    try:
        return _get_gemini_assistant_cached()
    except ConfigError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/chat", response_model=ChatResponse)
async def chat_with_assistant(
    payload: ChatRequest,
    repo: ProductRepository = Depends(get_product_repository),
    assistant: GeminiAssistant = Depends(get_gemini_assistant),
) -> ChatResponse:
    user_message = payload.message.strip()
    if not user_message:
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    try:
        snapshot = await repo.get_product_snapshot(payload.product_id)
    except ProductDataAccessError as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    if snapshot is None:
        raise HTTPException(status_code=404, detail="Product not found.")

    prompt = _build_prompt(snapshot, user_message)

    try:
        reply = await run_in_threadpool(assistant.generate_reply, prompt)
    except GeminiServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return ChatResponse(reply=reply)
