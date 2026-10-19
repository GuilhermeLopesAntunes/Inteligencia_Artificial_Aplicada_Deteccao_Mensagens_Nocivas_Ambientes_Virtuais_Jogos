from fastapi import APIRouter
from src.api.v1.incidents.list import router as list_router
from src.api.v1.incidents.detail import router as detail_router
from src.api.v1.incidents.view import router as view_router
from src.api.v1.incidents.status import router as status_router
from src.api.v1.incidents.delete import router as delete_router
from src.api.v1.incidents.report.generate import router as report_router

router = APIRouter()
router.include_router(list_router)
router.include_router(detail_router, prefix="/incidents")
router.include_router(view_router, prefix="/incidents")
router.include_router(status_router, prefix="/incidents")
router.include_router(delete_router, prefix="/incidents")
router.include_router(report_router, prefix="/incidents")
