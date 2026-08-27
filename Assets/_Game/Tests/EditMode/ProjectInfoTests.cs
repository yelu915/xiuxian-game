using NUnit.Framework;

namespace XianxiaRogue.Tests
{
    public sealed class ProjectInfoTests
    {
        [Test]
        public void Codename_IsConfigured()
        {
            Assert.That(ProjectInfo.Codename, Is.EqualTo("XianxiaRogue"));
        }
    }
}
