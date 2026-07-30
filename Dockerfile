# Use the official .NET SDK image to build the app
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /app

# Copy csproj and restore as distinct layers
COPY BookApiMcpServer.csproj ./
RUN dotnet restore ./BookApiMcpServer.csproj

# Copy the remaining source code
COPY . ./

# Build the application in release mode
RUN dotnet publish ./BookApiMcpServer.csproj -c Release -o out

# Build runtime image (aspnet required for Microsoft.NET.Sdk.Web / AspNetCore)
FROM mcr.microsoft.com/dotnet/aspnet:10.0

WORKDIR /app

# Copy published files from build image
COPY --from=build /app/out ./

# Optionally set environment variables
ENV BookApi__BaseUrl=${BOOK_API_URL}

EXPOSE 5289

# Set the entrypoint to run the server on container startup
ENTRYPOINT ["dotnet", "BookApiMcpServer.dll"]
