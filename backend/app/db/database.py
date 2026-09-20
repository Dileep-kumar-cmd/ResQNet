from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from sqlalchemy.pool import NullPool
from app.core.config import settings

connect_args = {}
if "sqlite" in settings.SQLALCHEMY_DATABASE_URL:
    connect_args = {"check_same_thread": False, "timeout": 30}
else:
    connect_args = {"ssl": "require"}

engine = create_async_engine(
    settings.SQLALCHEMY_DATABASE_URL,
    echo=False,
    future=True,
    poolclass=NullPool if "sqlite" in settings.SQLALCHEMY_DATABASE_URL else None,
    connect_args=connect_args
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
