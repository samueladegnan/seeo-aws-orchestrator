"""SEEO FastAPI application."""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from .config import Settings, get_settings
from .routers import environments, health
from .services.aws_service import AWSService
from .services.ttl_service import TTLService

settings = get_settings()


def _parse_cors_origins(raw: str) -> list[str]:
    """Parse a comma-separated CORS origins string into a list."""
    if raw.strip() == "*":
        return ["*"]
    return [origin.strip() for origin in raw.split(",") if origin.strip()]


@asynccontextmanager
async def lifespan(app: FastAPI):  # noqa: ARG001
    """Manage application lifespan: start TTL monitor on startup."""
    app.state.aws_service = AWSService(settings)  # type: ignore[attr-defined]
    app.state.ttl_service = TTLService(app.state.aws_service)  # type: ignore[attr-defined]
    app.state.ttl_service.start()
    try:
        yield
    finally:
        app.state.ttl_service.stop()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="Secure Ephemeral Environment Orchestrator for AWS",
    lifespan=lifespan,
)

# CORS: wildcard with credentials is rejected by browsers; set CORS_ALLOW_CREDENTIALS=false
# if you need to allow all origins.
app.add_middleware(
    CORSMiddleware,
    allow_origins=_parse_cors_origins(settings.cors_allow_origins),
    allow_credentials=settings.cors_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(health.router)
app.include_router(environments.router)


# Static assets and dashboard template
base_dir = os.path.dirname(os.path.abspath(__file__))
app.mount("/static", StaticFiles(directory=os.path.join(base_dir, "static")), name="static")
templates = Jinja2Templates(directory=os.path.join(base_dir, "templates"))


@app.get("/")
def dashboard(request: Request):
    """Serve the SEEO dashboard."""
    return templates.TemplateResponse("index.html", {"request": request})
