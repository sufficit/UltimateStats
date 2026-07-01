#!/bin/bash

# Deploy Web UI for UltimateStats CS 1.6 Ranking System
# Este script deploya a interface web para visualização de ranking

echo "Deploying UltimateStats Web UI..."

# Verifica se .NET está instalado
if ! command -v dotnet &> /dev/null; then
    echo "Error: .NET SDK not found. Please install .NET 8.0 or later."
    exit 1
fi

# Verifica se o diretório cs-ranking-web existe
if [ ! -d "cs-ranking-web" ]; then
    echo "Error: cs-ranking-web directory not found."
    exit 1
fi

cd cs-ranking-web

# Cria arquivo de configuração se não existir
if [ ! -f "config.json" ]; then
    if [ -f "config.example.json" ]; then
        cp config.example.json config.json
        echo "Created config.json from example. Please edit with your database credentials."
    else
        echo "Error: config.example.json not found."
        exit 1
    fi
fi

# Publica a aplicação
echo "Building and publishing application..."
dotnet publish -c Release -o ./publish

if [ $? -eq 0 ]; then
    echo "✓ Web UI published successfully to ./publish directory"
    echo "You can run the application with: dotnet ./publish/CSRanking.dll"
else
    echo "✗ Build failed"
    exit 1
fi