"""Auth API schemas for phone OTP flow."""

from __future__ import annotations

from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class OtpRequestIn(BaseModel):
    phone_number: str = Field(min_length=8, max_length=20, examples=["0244123456", "233244123456"])


class OtpRequestOut(BaseModel):
    status: str = "otp_sent"
    detail: str = "If the number is valid, a verification code has been sent."
    provider_reference: str | None = None
    expires_in_minutes: int


class OtpVerifyIn(BaseModel):
    phone_number: str = Field(min_length=8, max_length=20)
    code: str = Field(min_length=4, max_length=15)


class UserSessionOut(BaseModel):
    user_id: UUID
    phone_number: str
    is_new_user: bool
    role: str
    merchant_id: UUID | None
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    access_token_expires_in_minutes: int
    onboarding_required: bool
    pin_set: bool


class PinLoginIn(BaseModel):
    phone_number: str = Field(min_length=8, max_length=20)
    pin: str = Field(min_length=4, max_length=6)

    @field_validator("pin")
    @classmethod
    def pin_digits(cls, v: str) -> str:
        if not v.isdigit():
            msg = "PIN must contain only digits."
            raise ValueError(msg)
        return v


class PinSetIn(BaseModel):
    pin: str = Field(min_length=4, max_length=6)

    @field_validator("pin")
    @classmethod
    def pin_digits(cls, v: str) -> str:
        if not v.isdigit():
            msg = "PIN must contain only digits."
            raise ValueError(msg)
        return v


class PinSetOut(BaseModel):
    status: str = "ok"
    detail: str = "PIN saved."


class OnboardingIn(BaseModel):
    business_name: str = Field(min_length=2, max_length=255)
    business_type: str | None = Field(default=None, max_length=128)
    store_name: str | None = Field(default=None, max_length=255)


class OnboardingOut(BaseModel):
    merchant_id: UUID
    store_id: UUID
    business_name: str
    business_type: str | None
    onboarding_completed: bool = True
