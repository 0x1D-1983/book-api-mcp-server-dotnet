namespace BookApiMcpServer.Services;
using BookApiMcpServer.Models;
using System.Net.Http.Json;
using Microsoft.Extensions.Options;

public class BookService
{
    private readonly HttpClient httpClient;
    private readonly BookApiConfig config;

    public BookService(HttpClient httpClient, IOptionsMonitor<BookApiConfig> optionsMonitor)
    {
        this.httpClient = httpClient;
        this.config = optionsMonitor.CurrentValue;
    }

    public async Task<List<Book>> GetBooks()
    {
        var response = await httpClient.GetAsync($"{config.BaseUrl}/books");
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<List<Book>>() ?? new List<Book>();
    }

    public async Task<Book?> GetBookById(int id)
    {
        var response = await httpClient.GetAsync($"{config.BaseUrl}/books/{id}");
        if (response.IsSuccessStatusCode)
        {
            return await response.Content.ReadFromJsonAsync<Book>();
        }
        return null;
    }

    public async Task<Book?> CreateBook(Book book)
    {
        var response = await httpClient.PostAsJsonAsync($"{config.BaseUrl}/books", book);
        if (response.IsSuccessStatusCode)
        {
            return await response.Content.ReadFromJsonAsync<Book>();
        }
        return null;
    }

    public async Task<Book?> UpdateBook(Book book)
    {
        var response = await httpClient.PutAsJsonAsync($"{config.BaseUrl}/books/{book.Id}", book);
        if (response.IsSuccessStatusCode)
        {
            // UpdateBook returns 204 NoContent, so fetch the updated book
            if (response.StatusCode == System.Net.HttpStatusCode.NoContent)
            {
                return await GetBookById(book.Id);
            }
            // If it returns 200 with content, deserialize it
            return await response.Content.ReadFromJsonAsync<Book>();
        }
        return null;
    }

    public async Task<Book?> DeleteBook(int id)
    {
        var response = await httpClient.DeleteAsync($"{config.BaseUrl}/books/{id}");
        if (response.IsSuccessStatusCode)
        {
            // DeleteBook returns 204 NoContent, so we can't deserialize content
            // Return null to indicate successful deletion (no book to return)
            if (response.StatusCode == System.Net.HttpStatusCode.NoContent)
            {
                return null; // Successfully deleted, but no book to return
            }
            // If it returns 200 with content, deserialize it
            return await response.Content.ReadFromJsonAsync<Book>();
        }
        return null;
    }
}