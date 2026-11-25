using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace WashSmart.API.Migrations
{
    /// <inheritdoc />
    public partial class AddLoyaltyRulesToStoreConfig : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "DiamondMinPoints",
                table: "StoreConfigs",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "DiamondMinSpent",
                table: "StoreConfigs",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "DiamondRewardCode",
                table: "StoreConfigs",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "GoldMinPoints",
                table: "StoreConfigs",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "GoldMinSpent",
                table: "StoreConfigs",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "GoldRewardCode",
                table: "StoreConfigs",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<bool>(
                name: "LoyaltyAutoEnabled",
                table: "StoreConfigs",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "RegisterBonusPoints",
                table: "StoreConfigs",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "SilverMinPoints",
                table: "StoreConfigs",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "SilverMinSpent",
                table: "StoreConfigs",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DiamondMinPoints",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "DiamondMinSpent",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "DiamondRewardCode",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "GoldMinPoints",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "GoldMinSpent",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "GoldRewardCode",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "LoyaltyAutoEnabled",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "RegisterBonusPoints",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "SilverMinPoints",
                table: "StoreConfigs");

            migrationBuilder.DropColumn(
                name: "SilverMinSpent",
                table: "StoreConfigs");
        }
    }
}
