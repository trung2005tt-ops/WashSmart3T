using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace WashSmart.API.Migrations
{
    /// <inheritdoc />
    public partial class AddSealAndDrumTracking : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DrumCode",
                table: "Orders",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SealCode",
                table: "Orders",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SealStatus",
                table: "Orders",
                type: "nvarchar(max)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DrumCode",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "SealCode",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "SealStatus",
                table: "Orders");
        }
    }
}
