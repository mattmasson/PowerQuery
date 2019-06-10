// Connector based on the NASA/JPL Fireball API - https://ssd-api.jpl.nasa.gov/doc/fireball.html
section Fireball;

BaseUrl = "https://ssd-api.jpl.nasa.gov/fireball.api";

[DataSource.Kind="Fireball", Publish="Fireball.Publish"]
shared Fireball.Contents = () =>
    let
        source = Web.Contents(BaseUrl, [
            Query = [
                #"req-loc" = "true"
            ]
        ]),
        json = Json.Document(source),
        fields = json[fields],
        data = json[data],
        toTable = Table.FromList(data, Splitter.SplitByNothing()),
        withRecords = Table.AddColumn(toTable, "Custom", each Record.FromList([Column1], fields)),
        expand = Table.ExpandRecordColumn(withRecords, "Custom", fields),
        removeList = Table.RemoveColumns(expand, {"Column1"}),
        withTypes = Table.TransformColumnTypes(removeList,{{"date", type datetime}, {"energy", type number}, {"impact-e", type number}, {"lat", type number}, {"lat-dir", type text}, {"lon", type number}, {"lon-dir", type text}, {"alt", type number}, {"vel", type number}})
    in
        withTypes;

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
