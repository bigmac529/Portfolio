namespace Portfolio.Server.Models;

public sealed class Role
{
    public string Title { get; set; } = "";
    public string Company { get; set; } = "";
    public string Location { get; set; } = "";
    public string Start { get; set; } = "";
    public string? End { get; set; }
    public List<string> Bullets { get; set; } = new List<string>();
    public List<string> Tech { get; set; } = new List<string>();
}
