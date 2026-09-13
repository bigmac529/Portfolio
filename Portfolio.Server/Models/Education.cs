namespace Portfolio.Server.Models;

public sealed class Education
{
    public string Degree { get; set; } = "";
    public string School { get; set; } = "";
    public string Year { get; set; } = "";
    public string Location { get; set; } = "";
    public List<string> Highlights { get; set; } = new List<string>();
    public List<string> StudyAbroad { get; set; } = new List<string>();
    public List<string> Organizations { get; set; } = new List<string>();
}
