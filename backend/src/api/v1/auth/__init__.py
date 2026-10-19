from fastapi import APIRouter
from src.api.v1.auth.login import router as login_router
from src.api.v1.auth.me import router as me_router
from src.api.v1.auth.register import router as register_router

router = APIRouter()
router.include_router(login_router)
router.include_router(register_router)
router.include_router(me_router)
