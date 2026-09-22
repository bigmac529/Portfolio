using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Portfolio.Server.Utility;

public static class JsonSerializerDefault
{
    private static JsonSerializerOptions? _options;

    public static JsonSerializerOptions Options
    {
        get
        {
            if (_options == null)
            {
                _options = new JsonSerializerOptions();
                Configure(_options);
            }
            return _options;
        }
    }

    public static string Serialize<T>(T obj)
    {
        return JsonSerializer.Serialize(obj, Options);
    }

    public static T? Deserialize<T>(string json)
    {
        return JsonSerializer.Deserialize<T>(json, Options);
    }

    public static T? Clone<T>(T obj)
    {
        string json = JsonSerializer.Serialize(obj, Options);
        return JsonSerializer.Deserialize<T>(json, Options);
    }

    public static void Configure(JsonSerializerOptions options)
    {
        ArgumentNullException.ThrowIfNull(options, nameof(options));
        options.Converters.Add(new JsonStringEnumConverter());
        options.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        options.PropertyNameCaseInsensitive = true;
        options.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
        options.Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping;
    }

    public static bool CanSerializeToJson(object obj)
    {
        try
        {
            Serialize(obj);
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }
}
