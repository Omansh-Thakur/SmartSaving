import psycopg
from psycopg.rows import dict_row
import os
from datetime import datetime
from typing import Optional, Dict, Any
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def get_connection():
    if not DATABASE_URL:
        raise ValueError("DATABASE_URL environment variable is not set")
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)

def init_db():
    if not DATABASE_URL:
        return
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            hashed_password TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS tracked_products (
            user_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            target_price REAL,
            PRIMARY KEY (user_id, product_id)
        )
    """)
    conn.commit()
    conn.close()

def get_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
    row = cursor.fetchone()
    conn.close()
    if row:
        user_dict = dict(row)
        if 'created_at' in user_dict:
            user_dict['createdAt'] = user_dict.pop('created_at')
        return user_dict
    return None

def create_user(user_id: str, email: str, name: str, hashed_password: str) -> Dict[str, Any]:
    created_at = datetime.utcnow().isoformat()
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO users (id, email, name, hashed_password, created_at) VALUES (%s, %s, %s, %s, %s)",
        (user_id, email, name, hashed_password, created_at)
    )
    conn.commit()
    conn.close()
    
    return {
        "id": user_id,
        "email": email,
        "name": name,
        "createdAt": created_at
    }

def get_tracked_products(user_id: str) -> list[Dict[str, Any]]:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT product_id, target_price FROM tracked_products WHERE user_id = %s", (user_id,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(row) for row in rows]

def update_user_profile(user_id: str, name: str, hashed_password: Optional[str] = None) -> None:
    conn = get_connection()
    cursor = conn.cursor()
    if hashed_password:
        cursor.execute(
            "UPDATE users SET name = %s, hashed_password = %s WHERE id = %s",
            (name, hashed_password, user_id)
        )
    else:
        cursor.execute(
            "UPDATE users SET name = %s WHERE id = %s",
            (name, user_id)
        )
    conn.commit()
    conn.close()

def add_tracked_product(user_id: str, product_id: str, target_price: Optional[float] = None) -> None:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO tracked_products (user_id, product_id, target_price) 
        VALUES (%s, %s, %s)
        ON CONFLICT (user_id, product_id) 
        DO UPDATE SET target_price = EXCLUDED.target_price
        """,
        (user_id, product_id, target_price)
    )
    conn.commit()
    conn.close()

def update_target_price(user_id: str, product_id: str, target_price: Optional[float]) -> None:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE tracked_products SET target_price = %s WHERE user_id = %s AND product_id = %s",
        (target_price, user_id, product_id)
    )
    conn.commit()
    conn.close()

def remove_tracked_product(user_id: str, product_id: str) -> None:
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "DELETE FROM tracked_products WHERE user_id = %s AND product_id = %s",
        (user_id, product_id)
    )
    conn.commit()
    conn.close()
