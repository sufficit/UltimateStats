# CS Ranking Web

API para ranking CS 1.6 - UltimateStats

## 🚀 Funcionalidades

- Ranking de jogadores CS 1.6
- API REST para consulta de dados
- Interface web para visualização
- Configuração via arquivos JSON
- Suporte a ambiente de produção com configuração separada

## 📋 Pré-requisitos

- .NET 9.0 SDK
- MySQL 8.0+ (ou compatível)
- Docker (opcional, para desenvolvimento)

## 🔧 Configuração

### Configuração Local

1. Clone o repositório:
```bash
git clone <repositorio>
cd cs-ranking-web
```

2. Copie o arquivo de exemplo de configuração:
```bash
cp config.example.json config.json
```

3. Edite o arquivo `config.json` com suas credenciais de banco de dados:
```json
{
  "Database": {
    "Host": "localhost",
    "Port": 3306,
    "Database": "ultimate_stats",
    "Username": "seu_usuario",
    "Password": "sua_senha_segura"
  },
  "Ranking": {
    "MinKills": 10,
    "MinRounds": 5,
    "MinSkill": 0
  }
}
```

**⚠️ Importante:** O arquivo `config.json` contém dados sensíveis e está incluído no `.gitignore`. Nunca faça commit deste arquivo!

## 🏃 Executando

### Desenvolvimento Local

```bash
dotnet run
```

A API estará disponível em `http://localhost:8080`

### Com Docker

```bash
docker-compose up
```

## 📚 Documentação da API

### Health Check
- `GET /health` - Verifica o status da API

### Endpoints de Ranking
- `GET /api/ranking` - Lista o ranking completo
- `GET /api/ranking/player/{id}` - Detalhes de um jogador específico

### Swagger UI
- Acesse `http://localhost:8080/swagger` para documentação interativa

## 🔒 Segurança

- Configureções sensíveis devem estar no arquivo `config.json` (não versionado)
- Use senhas fortes e credenciais separadas para produção
- Em produção, use variáveis de ambiente ou serviço de gerenciamento de segredos

## 🛠️ Tecnologias

- .NET 9.0
- ASP.NET Core
- MySQL
- Swagger/OpenAPI
- Docker

## 📄 Licença

MIT

## 👨‍💻 Desenvolvimento

Para contribuir com o projeto:

1. Crie um branch a partir da `main`
2. Faça suas alterações
3. Teste localmente
4. Abra um Pull Request

## 📞 Suporte

Para suporte ou dúvidas, abra uma issue no repositório.