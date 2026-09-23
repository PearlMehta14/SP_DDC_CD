from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .database import engine, Base, SessionLocal
from . import models
from .routers import auth, users, dashboard, stock, rejection, reports
from .dependencies import supabase_admin
import traceback

Base.metadata.create_all(bind=engine)

app = FastAPI(title="DDC Diamonds Backend")

if settings.cors_origins:
    origins = [origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()]
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(dashboard.router)
app.include_router(stock.router)
app.include_router(rejection.router)
app.include_router(reports.router)

@app.on_event("startup")
def startup_event():
    db = SessionLocal()
    try:
        admin_email = settings.initial_admin_email
        existing_admin = db.query(models.User).filter(models.User.email == admin_email).first()
        if not existing_admin:
            print(f"Initial admin {admin_email} not found. Creating...")
            try:
                res = supabase_admin.auth.admin.create_user({
                    "email": admin_email,
                    "password": "dilpesh123",
                    "email_confirm": True
                })
                supabase_user_id = res.user.id
            except Exception as e:
                print(f"User might exist in Supabase auth, fetching id... {str(e)}")
                try:
                    users_list = supabase_admin.auth.admin.list_users()
                    found = False
                    for u in users_list:
                        if u.email == admin_email:
                            supabase_user_id = u.id
                            found = True
                            break
                    if not found:
                        raise Exception("Failed to create or find admin user in Supabase")
                except Exception as ex:
                    print(f"Could not fetch list of users (check service_role_key): {ex}")
                    return
            
            new_admin = models.User(
                id=supabase_user_id,
                name="Dilpesh",
                email=admin_email,
                role="ADMIN",
                is_active=True
            )
            db.add(new_admin)
            db.commit()
            print("Initial admin created successfully.")
    except Exception as exc:
        print("Failed during admin initialization:")
        traceback.print_exc()
    finally:
        db.close()

@app.get("/health")
def health_check():
    return {"status": "ok"}
