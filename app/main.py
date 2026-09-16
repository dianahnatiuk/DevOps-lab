from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from sqlalchemy import Column, Integer, String
from app.database import Base, engine, SessionLocal

app = FastAPI()

class Item(Base):
    __tablename__ = "items"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)

Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def read_root():
    return {"message": "DevOps Lab 1 API is running"}

@app.post("/items/")
def create_item(name: str, db: Session = Depends(get_db)):
    db_item = Item(name=name)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item