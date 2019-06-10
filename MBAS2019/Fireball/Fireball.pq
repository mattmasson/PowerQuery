// Connector based on the NASA/JPL Fireball API - https://ssd-api.jpl.nasa.gov/doc/fireball.html
section Fireball;

BaseUrl = "https://ssd-api.jpl.nasa.gov/fireball.api";

[DataSource.Kind="Fireball", Publish="Fireball.Publish"]
shared Fireball.Contents = () =>
    let
        source = Web.Contents(BaseUrl),
        json = Json.Document(source)
    in
        json;

Fireball = [
    Authentication = [
        Anonymous = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
Fireball.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Fireball.Icons,
    SourceTypeImage = Fireball.Icons
];

Fireball.Icons = [
    Icon16 = { Extension.Contents("Fireball16.png"), Extension.Contents("Fireball20.png"), Extension.Contents("Fireball24.png"), Extension.Contents("Fireball32.png") },
    Icon32 = { Extension.Contents("Fireball32.png"), Extension.Contents("Fireball40.png"), Extension.Contents("Fireball48.png"), Extension.Contents("Fireball64.png") }
];
