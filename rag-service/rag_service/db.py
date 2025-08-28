from sqlalchemy import (MetaData, Table, Column, Integer, String, ForeignKey, create_engine)
from sqlalchemy.sql import select
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

DATABASE_URL = os.environ.get('DATABASE_URL', 'sqlite:///./rag.db')

engine: Engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

metadata = MetaData()

categories = Table(
    'categories', metadata,
    Column('id', Integer, primary_key=True, autoincrement=True),
    Column('name', String, unique=True, nullable=False)
)

files = Table(
    'files', metadata,
    Column('id', Integer, primary_key=True, autoincrement=True),
    Column('name', String, nullable=False),
    Column('path', String, nullable=False),
    Column('category_id', Integer, ForeignKey('categories.id'), nullable=False)
)

metadata.create_all(bind=engine)

def get_category_by_name(conn, name: str):
    return conn.execute(select(categories).where(categories.c.name == name)).fetchone()

