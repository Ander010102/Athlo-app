@echo off
REM Criando pastas para o projeto Athlo

mkdir lib\core\constants
mkdir lib\core\services
mkdir lib\core\models
mkdir lib\core\utils

mkdir lib\config

mkdir lib\features\auth\pages
mkdir lib\features\auth\widgets
mkdir lib\features\auth\controller

mkdir lib\features\home\pages
mkdir lib\features\home\widgets
mkdir lib\features\home\controller

mkdir lib\features\community\pages
mkdir lib\features\community\widgets
mkdir lib\features\community\controller

mkdir lib\features\my_communities\pages
mkdir lib\features\my_communities\widgets
mkdir lib\features\my_communities\controller

mkdir lib\features\chat\pages
mkdir lib\features\chat\widgets
mkdir lib\features\chat\controller

mkdir lib\shared

mkdir assets\icons
mkdir assets\images
mkdir assets\fonts

echo Estrutura criada com sucesso!
pause
