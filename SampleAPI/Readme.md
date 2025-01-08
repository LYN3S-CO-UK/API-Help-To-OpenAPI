# Dummy-ASP.NET-API

Dummy-ASP.NET-API is a simple ASP.NET Core Web API project designed to demonstrate basic API functionalities. This project can be used as a test for API-Help-To-OpenAPI.ps1 scraper. 

## Features

- Basic CRUD operations
- RESTful API design
- Simple data model
- In-memory data storage

## Getting Started

### Prerequisites

- [.NET Core SDK](https://dotnet.microsoft.com/download) (version 3.1 or later)

### Installation

1. Clone the repository:

    ```sh
    git clone https://github.com/yourusername/SampleAPI.git
    cd SampleAPI
    ```

2. Restore the dependencies:

    ```sh
    dotnet restore
    ```

### Running the API

1. Build and run the API:

    ```sh
    dotnet run
    ```

2. The API will be available at `https://localhost:5001` or `http://localhost:5000`.

### Testing the API

You can use tools like [Postman](https://www.postman.com/) or [curl](https://curl.se/) to test the API endpoints.

### API Endpoints

- `GET /api/items` - Retrieve all items
- `GET /api/items/{id}` - Retrieve an item by ID
- `POST /api/items` - Create a new item
- `PUT /api/items/{id}` - Update an existing item
- `DELETE /api/items/{id}` - Delete an item by ID

## Contributing

Feel free to submit issues or pull requests if you have any improvements or bug fixes.

## License

This project is licensed under the MIT License.