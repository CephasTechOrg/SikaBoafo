@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo.
echo ========================================
echo  SikaBoafo local CI (pre-push checks)
echo ========================================
echo.

REM ---------- Mobile (matches .github/workflows/mobile-ci.yml) ----------
echo [1/2] Mobile: flutter pub get, analyze, test
echo.
pushd mobile || exit /b 1
call flutter pub get || (popd & exit /b 1)
call flutter analyze --fatal-infos || (popd & exit /b 1)
call flutter test --reporter expanded || (popd & exit /b 1)
popd || exit /b 1

echo.
REM ---------- Backend (matches .github/workflows/backend-ci lint-and-test) ----------
echo [2/2] Backend: pip, ruff, pytest
echo.

pushd backend || exit /b 1

if exist "venv\Scripts\python.exe" (
  set "PY=venv\Scripts\python.exe"
  echo Using backend\venv
) else (
  set "PY=python"
  echo Using system Python (create backend\venv for an isolated env)
)

"%PY%" -m pip install --upgrade pip -q || (popd & exit /b 1)
"%PY%" -m pip install -r requirements.txt -q || (popd & exit /b 1)
if exist requirements-dev.txt (
  "%PY%" -m pip install -r requirements-dev.txt -q || (popd & exit /b 1)
)

"%PY%" -m ruff check app || (popd & exit /b 1)
"%PY%" -m pytest app/tests -v --tb=short || (popd & exit /b 1)

popd || exit /b 1

REM ---------- Optional: Docker image (matches backend-ci docker-build job) ----------
where docker >nul 2>nul
if errorlevel 1 (
  echo.
  echo [SKIP] Docker not on PATH; skipping image build.
) else (
  echo.
  echo [extra] Backend Docker build
  docker build -t sikaboafo-backend:ci ./backend || exit /b 1
)

echo.
echo ========================================
echo  All local CI checks passed.
echo ========================================
echo.
exit /b 0
