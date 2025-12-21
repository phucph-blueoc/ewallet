from fastapi import APIRouter
from app.api.v1.endpoints import auth, wallets, contacts, bank_cards, bills, budgets, savings_goals, analytics, notifications, alerts, devices, security

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(wallets.router, prefix="/wallets", tags=["wallets"])
api_router.include_router(contacts.router, prefix="/contacts", tags=["contacts"])
api_router.include_router(bank_cards.router, prefix="/cards", tags=["bank_cards"])
api_router.include_router(bills.router, prefix="/bills", tags=["bills"])
api_router.include_router(budgets.router, prefix="/budgets", tags=["budgets"])
api_router.include_router(savings_goals.router, prefix="/savings-goals", tags=["savings_goals"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(alerts.router, prefix="/alerts", tags=["alerts"])
api_router.include_router(devices.router, prefix="/devices", tags=["devices"])
api_router.include_router(security.router, prefix="/security", tags=["security"])
