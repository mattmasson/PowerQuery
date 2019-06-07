// Sample connector based on NASA APIs - https://api.nasa.gov/api.html
[Version="1.0.0"]
section NASA;

// Load the default API key we bundle with the connector
DefaultApiKey = Text.FromBinary(Extension.Contents("apikey"));

// Endpoint URLs
Endpoint_Fireball = "https://ssd-api.jpl.nasa.gov/fireball.api";

// Schemas
// TODO: locale for change table type
FireballResultType = type table [
    date = DateTime.Type,
    lat = Number.Type,
    #"lat-dir" = Text.Type,
    lon = Number.Type,
    #"lon-dir" = Text.Type,
    alt = Number.Type,
    vel = Number.Type,
    energy = Number.Type,
    #"impact-e" = Number.Type,
    vx = Number.Type,
    vy = Number.Type,
    vz = Number.Type
];

[DataSource.Kind="NASA", Publish="NASA.Publish"]
shared NASA.Contents = ContentsImpl;

ContentsImpl = () => 
    let
        objects = #table(
            {"Name",       "Key",        "Data",              "ItemKind", "ItemName", "IsLeaf"},{
            {"Fireball",   "fireball",    FireballData(),     "Table",    "Table",    true}
        }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

FireballData = () as table => 
    let
        result = NasaApiRequest(Endpoint_Fireball, false, [#"vel-comp" = "true"]),
        // Transform the data into a tabular format
        columns = result[fields],
        data = result[data],
        toTable = Table.FromList(data, Splitter.SplitByNothing(), {"Data"}),
        toRecords = Table.TransformColumns(toTable, {{"Data", each Record.FromList(_, columns)}}),
        expanded = Table.ExpandRecordColumn(toRecords, "Data", columns),
        // Apply table schema to get the right types
        withType = Table.ChangeType(expanded, FireballResultType)
    in
        withType;

GetEffectiveApiKey = () as text =>
    let
        credentials = Extension.CurrentCredential(),
        keyProvided = credentials[AuthenticationKind]? = "Key"
    in
        if (keyProvided) then 
            credentials[Key]
        else
            DefaultApiKey;

// Base function used to call the NASA APIs.
NasaApiRequest = (url as text, includeApiKey as logical, optional queryParameters as record) as record =>
    let
        query = if (queryParameters <> null) then queryParameters else [],
        queryWithCredentials = query & [ api_key = GetEffectiveApiKey() ],
        headers = [ Accept = "application/json" ],
        request = Web.Contents(url, [ 
            Query = if (includeApiKey) then queryWithCredentials else query,
            ManualCredentials = true,
            Headers = headers ]),
        json = Json.Document(request)
    in
        json;

// Data Source Kind description
NASA = [
    Authentication = [
        Key = [],
        Anonymous = []
    ]
];

// Data Source UI publishing description
NASA.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://api.nasa.gov/index.html",
    SourceImage = NASA.Icons,
    SourceTypeImage = NASA.Icons
];

NASA.Icons = [
    Icon16 = { Extension.Contents("NASA16.png"), Extension.Contents("NASA20.png"), Extension.Contents("NASA24.png"), Extension.Contents("NASA32.png") },
    Icon32 = { Extension.Contents("NASA32.png"), Extension.Contents("NASA40.png"), Extension.Contents("NASA48.png"), Extension.Contents("NASA64.png") }
];

// 
// Load common library functions
// 
// TEMPORARY WORKAROUND until we're able to reference other M modules
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

Table.ChangeType = Extension.LoadFunction("Table.ChangeType.pqm");
Table.ToNavigationTable = Extension.LoadFunction("Table.ToNavigationTable.pqm");

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = Diagnostics[LogValue];
Diagnostics.LogFailure = Diagnostics[LogFailure];
Diagnostics.WrapHandlers = Diagnostics[WrapHandlers];