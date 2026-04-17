from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional

import database
from auth import get_current_user

router = APIRouter(prefix="/track", tags=["tracking"])

class TrackedProductItem(BaseModel):
    product_id: str
    target_price: Optional[float] = None

class TargetPriceUpdate(BaseModel):
    target_price: Optional[float] = None

@router.get("", response_model=List[TrackedProductItem])
async def get_tracked_items(current_user: dict = Depends(get_current_user)):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID missing")
    
    items = database.get_tracked_products(user_id)
    return [TrackedProductItem(product_id=row["product_id"], target_price=row["target_price"]) for row in items]

@router.post("", response_model=dict)
async def add_tracked_item(item: TrackedProductItem, current_user: dict = Depends(get_current_user)):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID missing")
    
    database.add_tracked_product(user_id, item.product_id, item.target_price)
    return {"success": True, "message": "Product tracked successfully"}

@router.put("/{product_id}/target", response_model=dict)
async def update_target(product_id: str, update: TargetPriceUpdate, current_user: dict = Depends(get_current_user)):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID missing")
    
    database.update_target_price(user_id, product_id, update.target_price)
    return {"success": True, "message": "Target price updated"}

@router.delete("/{product_id}", response_model=dict)
async def remove_tracked_item(product_id: str, current_user: dict = Depends(get_current_user)):
    user_id = current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=400, detail="User ID missing")
    
    database.remove_tracked_product(user_id, product_id)
    return {"success": True, "message": "Product untracked successfully"}
