@echo off
echo Testing NextOra Deployment
echo ========================

echo.
echo Checking Docker containers...
docker-compose ps

echo.
echo Testing Backend (localhost:3000)...
curl -s -o nul -w "Status: %%{http_code}" http://localhost:3000
echo.

echo Testing Frontend (localhost:8080)...
curl -s -o nul -w "Status: %%{http_code}" http://localhost:8080
echo.

echo.
echo Access URLs:
echo Frontend: http://localhost:8080
echo Backend:  http://localhost:3000
echo Database: localhost:5432

echo.
echo Useful commands:
echo View logs:    docker-compose logs -f
echo Stop:         docker-compose down
echo Restart:      docker-compose restart
