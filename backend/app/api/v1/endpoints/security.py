from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Optional
from datetime import datetime

from app.core.database import get_db
from app.core.security import get_current_user
from app.core.rate_limit import limiter, GENERAL_LIMIT
from app.models import User, SecurityHistory, UserDevice
from app.schemas import SecurityHistoryResponse

router = APIRouter()


@router.get("/history", response_model=List[SecurityHistoryResponse])
@limiter.limit(GENERAL_LIMIT)
async def get_security_history(
    request: Request,
    limit: int = 50,
    offset: int = 0,
    action_type: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get security history for current user.
    
    - Returns list of security events
    - Can filter by action_type
    - Sorted by created_at (most recent first)
    """
    query = db.query(SecurityHistory).filter(
        SecurityHistory.user_id == current_user.id
    )
    
    if action_type:
        query = query.filter(SecurityHistory.action_type == action_type)
    
    # Get total count for pagination
    total = query.count()
    
    # Get paginated results
    history = query.order_by(desc(SecurityHistory.created_at)).offset(offset).limit(limit).all()
    
    # Add device_name to response
    result = []
    for item in history:
        device_name = None
        if item.device_id:
            device = db.query(UserDevice).filter(UserDevice.id == item.device_id).first()
            if device:
                device_name = device.device_name
        
        history_dict = {
            "id": item.id,
            "user_id": item.user_id,
            "action_type": item.action_type,
            "description": item.description,
            "ip_address": item.ip_address,
            "user_agent": item.user_agent,
            "device_id": item.device_id,
            "device_name": device_name,
            "created_at": item.created_at
        }
        result.append(SecurityHistoryResponse(**history_dict))
    
    return result

