using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace WashSmart.API.Migrations
{
    /// <inheritdoc />
    public partial class AddPlainPasswordToUser : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(@"
                IF COL_LENGTH('Users', 'PlainPassword') IS NULL
                BEGIN
                    ALTER TABLE [Users] ADD [PlainPassword] nvarchar(max) NULL;
                END
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PlainPassword",
                table: "Users");
        }
    }
}
