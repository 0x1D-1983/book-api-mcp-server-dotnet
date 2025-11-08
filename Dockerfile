# Use the official .NET SDK image to build the app
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /app

# Copy csproj and restore as distinct layers
COPY BookApiMcpServer.csproj ./
RUN dotnet restore ./BookApiMcpServer.csproj

# Copy the remaining source code
COPY . ./

# Build the application in release mode
RUN dotnet publish ./BookApiMcpServer.csproj -c Release -o out

# Build runtime image
FROM mcr.microsoft.com/dotnet/runtime:9.0

WORKDIR /app

# Copy published files from build image
COPY --from=build /app/out ./

# Optionally set environment variables
ENV BookApi__BaseUrl=${BOOK_API_URL}

# Set the entrypoint to run the server on container startup
ENTRYPOINT ["dotnet", "BookApiMcpServer.dll"]
