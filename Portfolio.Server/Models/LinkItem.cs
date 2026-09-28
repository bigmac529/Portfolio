namespace Portfolio.Server.Models;

public sealed class LinkItem
{
    public string Label { get; set; } = "";
    public string Url { get; set; } = "";

    /// <summary>Optional short tooltip text for the hero button (omitted from JSON when null).</summary>
    public string? Description { get; set; }
}
