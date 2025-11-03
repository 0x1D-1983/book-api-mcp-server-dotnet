namespace BookApiMcpServer.Tools;
using ModelContextProtocol.Server;
using System.ComponentModel;
using BookApiMcpServer.Services;
using BookApiMcpServer.Models;
using System.Text.Json;

[McpServerToolType]
public static class BookTools
{
    [McpServerTool, Description("Get all books")]
    public static async Task<List<string>> GetBooks(BookService bookService)
    {
        var books = await bookService.GetBooks();

        return books.Select(book => JsonSerializer.Serialize(book)).ToList();
    }

    [McpServerTool, Description("Get a book by id")]
    public static async Task<string> GetBookById(BookService bookService, int id)
    {
        var book = await bookService.GetBookById(id);
        return book != null ? JsonSerializer.Serialize(book) : "";
    }

    [McpServerTool, Description("Create a new book")]
    public static async Task<string> CreateBook(BookService bookService, Book book)
    {
        var createdBook = await bookService.CreateBook(book);
        return createdBook != null ? JsonSerializer.Serialize(createdBook) : "";
    }

    [McpServerTool, Description("Update a book")]
    public static async Task<string> UpdateBook(BookService bookService, Book book)
    {
        var updatedBook = await bookService.UpdateBook(book);
        if (updatedBook == null)
        {
            throw new InvalidOperationException($"Failed to update book with id {book.Id}. The update may have succeeded, but the updated book could not be retrieved.");
        }
        return JsonSerializer.Serialize(updatedBook);
    }

    [McpServerTool, Description("Delete a book")]
    public static async Task<string> DeleteBook(BookService bookService, int id)
    {
        var deletedBook = await bookService.DeleteBook(id);
        return deletedBook != null ? JsonSerializer.Serialize(deletedBook) : "";
    }
}