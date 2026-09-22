namespace Portfolio.Server.Models;

public sealed class SkillGroup
{
    public string Name { get; set; } = "";
    public List<SkillItem> Items { get; set; } = new List<SkillItem>();
}
