using Microsoft.AspNetCore.Mvc;
using Portfolio.Server.Models;
using Portfolio.Server.Utility;

namespace Portfolio.Server.Controllers;

[Route("api/[controller]")]
[ApiController]
public class ProfileController : ControllerBase
{
    private readonly ILogger logger;
    private readonly IWebHostEnvironment env;
    private static Profile? profile;

    public ProfileController(ILogger<ProfileController> logger, IWebHostEnvironment env)
    {
        this.logger = logger;
        this.env = env;
        if (profile == null)
        {
            string path = Path.Combine(Environment.CurrentDirectory, "profile.json");
            string json = System.IO.File.ReadAllText(path);
            profile = JsonSerializerDefault.Deserialize<Profile>(json);
        }
    }

    [HttpGet]
    public IActionResult Get()
    {
        return Ok(profile);
    }
}
