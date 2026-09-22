namespace Portfolio.Server.Models;

public sealed class Profile
{
    public string Name { get; set; } = "";
    public string Location { get; set; } = "";
    public string Email { get; set; } = "";
    public string Headline { get; set; } = "";
    public string Summary { get; set; } = "";
    public List<LinkItem> Links { get; set; } = new List<LinkItem>();
    public List<SkillGroup> Skills { get; set; } = new List<SkillGroup>();
    public List<Role> Experience { get; set; } = new List<Role>();
    public List<Education> Education { get; set; } = new List<Education>();
}
