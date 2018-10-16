// Overview of the Steam Web API: https://developer.valvesoftware.com/wiki/Steam_Web_API#License_and_further_documentation
section Steam;

ApiKey = LoadFromResource("apikey");

[DataSource.Kind="Steam", Publish="Steam.Publish"]
shared Steam.Contents = Value.ReplaceType(ContentsImpl, SteamContentsType);

SteamContentsType = type function (
    profile as (type text meta [
        Documentation.FieldCaption = "Profile",
        Documentation.FieldDescription = "Steam public profile name",
        DataSource.Path = false // don't include in data source path calculation
    ]),
    optional steamId as (type text meta [
        Documentation.FieldCaption = "Steam ID",
        Documentation.FieldDescription = "SteamID64 value. You can provide this value to avoid the additional lookup."
    ]))

    as table meta [
        Documentation.Name = "Steam Games",
        Documentation.LongDescription = "Steam Games - list all games you own on the steam platform"
    ];

ContentsImpl = (profile as text, optional steamId as nullable text) =>
    let
        _steamId = if (steamId <> null) then steamId else try LookupSteamIdFromProfile(profile) otherwise error Error.Record("DataSource.Error", "Error retrieving SteamId"),
        Source = GetOwnedGames(_steamId),
        response = Source[response],
        games = response[games],
        #"Converted to Table" = Table.FromList(games, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"appid", "name", "playtime_forever", "img_icon_url", "img_logo_url", "has_community_visible_stats"}),
        #"Cleaned Text" = Table.TransformColumns(#"Expanded Column1",{{"name", Text.Clean}}),
        #"Replaced Value" = Table.ReplaceValue(#"Cleaned Text","™","",Replacer.ReplaceText,{"name"}),
        #"Replaced Value1" = Table.ReplaceValue(#"Replaced Value","®","",Replacer.ReplaceText,{"name"}),
        #"Changed Type" = Table.TransformColumnTypes(#"Replaced Value1",{{"appid", Int64.Type}, {"playtime_forever", Int64.Type}, {"img_icon_url", type text}, {"img_logo_url", type text}, {"has_community_visible_stats", type logical}}),
        replaceNull = Table.ReplaceValue(#"Changed Type",null,false,Replacer.ReplaceValue,{"has_community_visible_stats"}),
        setIconUrl = Table.AddColumn(replaceNull, "icon_url", each MakeImageUrl([appid], [img_icon_url]), Uri.Type),
        setLogoUrl = Table.AddColumn(setIconUrl, "logo_url", each MakeImageUrl([appid], [img_logo_url]), Uri.Type),
        remove = Table.RemoveColumns(setLogoUrl, {"img_icon_url", "img_logo_url"})//,
        //addScore = Table.AddColumn(remove, "score", each LookupGameScore([name]), type text)
    in
        remove;

GetOwnedGames = (steamId as text) =>
    let
        query = [
            key  = ApiKey, 
            steamid = steamId,
            format = "json",
            include_appinfo = "1"
        ],
        Source = Json.Document(Web.Contents("https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/", [Query = query]))
    in
        Source;

LookupSteamIdFromProfile = (profile as text) as text =>
    let
        _profile = Text.Trim(Text.Clean(profile)),
        Source = Xml.Document(Web.Contents("https://steamcommunity.com/id/" & _profile & "?xml=1")),
        Value = Source{0}[Value],
        GetId = Table.SelectRows(Value, each [Name] = "steamID64"),
        id = GetId{0}[Value]
    in
        id;

BaseImageUrl = "https://media.steampowered.com/steamcommunity/public/images/apps/";

// format is https://media.steampowered.com/steamcommunity/public/images/apps/<appId>/<url>.jpg
MakeImageUrl = (appId as number, url as nullable text) as nullable text =>
    if (url = null or url = "") then 
        null 
    else
        BaseImageUrl & Number.ToText(appId) & "/" & url & ".jpg";

LookupGameScore = (title as text) as nullable text =>
    let
        _title = Text.Trim(title),
        score = try
            let
                query = [ search = _title, numrev= "3", site= "pc" ],
                contents = Web.Contents("http://www.gamerankings.com/browse.html", [Query = query]),
                Source = Table.FromColumns({Lines.FromBinary(contents)}),
                Trim = Table.TransformColumns(Source,{},Text.Trim),
                Top = Table.FirstN(Trim,400),
                Filter = Table.SelectRows(Top, each Text.StartsWith([Column1], "<td><span style=""font-size: 35px"">")),
                Extract = Table.TransformColumns(Filter, {{"Column1", each Text.BetweenDelimiters(_, "<b>", "</b>", 0, 0), type text}}),
                GetValue = Table.First(Extract)[Column1]
            in
                GetValue otherwise null,
        // Sometimes the full title doesn't work.
        // If we get back null, try searching for the text after ":".
        // If there is nothing after the ":", then give up and return null
        return =
            if (score = null) then
                let
                    postfix = Text.AfterDelimiter(_title, ":"),
                    newCall = if (postfix <> "") then @LookupGameScore(postfix) else null
                in
                    newCall
            else
                score
    in
        return;

// Data Source Kind description
Steam = [
    Authentication = [
        Implicit = []
    ]
];

// Data Source UI publishing description
Steam.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    SourceImage = Steam.Icons,
    SourceTypeImage = Steam.Icons
];

Steam.Icons = [
    Icon16 = { Extension.Contents("Steam16.png"), Extension.Contents("Steam20.png"), Extension.Contents("Steam24.png"), Extension.Contents("Steam32.png") },
    Icon32 = { Extension.Contents("Steam32.png"), Extension.Contents("Steam40.png"), Extension.Contents("Steam48.png"), Extension.Contents("Steam64.png") }
];

// Common functions
LoadFromResource = (name as text) as text => 
    try 
        Text.FromBinary(Extension.Contents(name))
    otherwise
        error Error.Unexpected("Resource not found: '" & name & "'. Does the file exist in your project, and is its Build Action set to 'Compile'?");