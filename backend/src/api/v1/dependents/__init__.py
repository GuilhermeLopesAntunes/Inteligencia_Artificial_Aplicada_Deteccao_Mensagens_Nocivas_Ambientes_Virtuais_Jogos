from fastapi import APIRouter
from src.api.v1.dependents.create import router as create_router
from src.api.v1.dependents.list import router as list_router
from src.api.v1.dependents.threshold import router as threshold_router

router = APIRouter()
router.include_router(create_router)
router.include_router(list_router)
router.include_router(threshold_router)
