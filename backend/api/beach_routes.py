from fastapi import APIRouter, HTTPException, status
from schemas.beach import BeachListResponse, BeachResponse
from services.mock_data import MOCK_BEACHES

router = APIRouter(prefix="/beaches", tags=["beaches"])


@router.get("", response_model=BeachListResponse)
def get_beaches() -> BeachListResponse:
    return BeachListResponse(beaches=[BeachResponse(**beach) for beach in MOCK_BEACHES])


@router.get("/{id}", response_model=BeachResponse)
def get_beach_by_id(id: int) -> BeachResponse:
    for beach in MOCK_BEACHES:
        if beach["id"] == id:
            return BeachResponse(**beach)
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Beach with id {id} not found",
    )
