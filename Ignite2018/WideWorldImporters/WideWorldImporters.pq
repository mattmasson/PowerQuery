// Adapted from the SqlODBC sample: https://github.com/Microsoft/DataConnectors/tree/master/samples/ODBC/SqlODBC
section WideWorldImporters;

EnableTraceOutput = false;

/****************************
 * ODBC Driver Configuration
 ****************************/

Config_DriverName = "SQL Server Native Client 11.0";
Config_SqlConformance = ODBC[SQL_SC][SQL_SC_SQL92_FULL];  // null, 1, 2, 4, 8
Config_UseParameterBindings = false;  // true, false, null
Config_StringLiterateEscapeCharacters  = { "\" }; // ex. { "\" }
Config_UseCastInsteadOfConvert = null; // true, false, null
Config_SupportsTop = true; // true, false
Config_EnableDirectQuery = true;    // true, false

[DataSource.Kind="WideWorldImporters", Publish="WideWorldImporters.Publish"]
shared WideWorldImporters.Contents = () => FormatNavTable(OdbcImpl());

// Creates a friendlier view of the default ODBC nav table.
// Note that adding/removing columns will remove
// the nav table metadata (since it changes the table type),
// adding/removing rows will not impact its nav tableness.
FormatNavTable = (root as table) as table => 
    let
        database = root{[Name="WideWorldImportersDW"]}[Data],
        // we only want tables in the Dimension and Fact schemas
        filtered = Table.SelectRows(database, each [Name] = "Dimension" or [Name] = "Fact")
    in
        filtered;

// returns the result of the call to Odbc.DataSource
OdbcImpl = () =>
    let
        ConnectionString = [
            Driver = Config_DriverName,
            Server = "localhost",
            Database = "WideWorldImportersDW",
            ApplicationIntent = "readonly"
        ],

        Credential = Extension.CurrentCredential(),
		CredentialConnectionString =
            if Credential[AuthenticationKind]? = "UsernamePassword" then
                // set connection string parameters used for basic authentication
                [ UID = Credential[Username], PWD = Credential[Password] ]
            else if (Credential[AuthenticationKind]? = "Windows") then
                // set connection string parameters used for windows/kerberos authentication
                [ Trusted_Connection="Yes" ]
            else
                error Error.Record("Error", "Unhandled authentication kind: " & Credential[AuthenticationKind]?),
        
        defaultConfig = BuildOdbcConfig(),

        options = [
            HierarchicalNavigation = true, 
            HideNativeQuery = true,
            SoftNumbers = true,
            TolerateConcatOverflow = true,
            ClientConnectionPooling = true,

            SqlCapabilities = defaultConfig[SqlCapabilities] & [
                FractionalSecondsScale = 3
            ],

            SQLGetInfo = defaultConfig[SQLGetInfo] & [
                // place custom overrides here
                SQL_SQL92_PREDICATES = ODBC[SQL_SP][All],
                SQL_AGGREGATE_FUNCTIONS = ODBC[SQL_AF][All]
            ]
        ],

        OdbcDatasource = Odbc.DataSource(ConnectionString, options)
    in
        OdbcDatasource; 

// Data Source Kind description
WideWorldImporters = [
    TestConnection = (dataSourcePath) => { "WideWorldImporters.Contents" },
    // Set supported types of authentication
    Authentication = [
        Windows = []
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
WideWorldImporters.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",

    SupportsDirectQuery = Config_EnableDirectQuery,

    SourceImage = WideWorldImporters.Icons,
    SourceTypeImage = WideWorldImporters.Icons
];

WideWorldImporters.Icons = [
    Icon16 = { Extension.Contents("WideWorldImporters16.png"), Extension.Contents("WideWorldImporters20.png"), Extension.Contents("WideWorldImporters24.png"), Extension.Contents("WideWorldImporters32.png") },
    Icon32 = { Extension.Contents("WideWorldImporters32.png"), Extension.Contents("WideWorldImporters40.png"), Extension.Contents("WideWorldImporters48.png"), Extension.Contents("WideWorldImporters64.png") }
];

// build settings based on configuration variables
BuildOdbcConfig = () as record =>
    let        
        defaultConfig = [
            SqlCapabilities = [],
            SQLGetFunctions = [],
            SQLGetInfo = []
        ],

        withParams =
            if (Config_UseParameterBindings = false) then
                let 
                    caps = defaultConfig[SqlCapabilities] & [ 
                        SqlCapabilities = [
                            SupportsNumericLiterals = true,
                            SupportsStringLiterals = true,                
                            SupportsOdbcDateLiterals = true,
                            SupportsOdbcTimeLiterals = true,
                            SupportsOdbcTimestampLiterals = true
                        ]
                    ],
                    funcs = defaultConfig[SQLGetFunctions] & [
                        SQLGetFunctions = [
                            SQL_API_SQLBINDPARAMETER = false
                        ]
                    ]
                in
                    defaultConfig & caps & funcs
            else
                defaultConfig,
                
        withEscape = 
            if (Config_StringLiterateEscapeCharacters <> null) then 
                let
                    caps = withParams[SqlCapabilities] & [ 
                        SqlCapabilities = [
                            StringLiteralEscapeCharacters = Config_StringLiterateEscapeCharacters
                        ]
                    ]
                in
                    withParams & caps
            else
                withParams,

        withTop =
            let
                caps = withEscape[SqlCapabilities] & [ 
                    SqlCapabilities = [
                        SupportsTop = Config_SupportsTop
                    ]
                ]
            in
                withEscape & caps,

        withCastOrConvert = 
            if (Config_UseCastInsteadOfConvert = true) then
                let
                    caps = withTop[SQLGetFunctions] & [ 
                        SQLGetFunctions = [
                            SQL_CONVERT_FUNCTIONS = 0x2 /* SQL_FN_CVT_CAST */
                        ]
                    ]
                in
                    withTop & caps
            else
                withTop,

        withSqlConformance =
            if (Config_SqlConformance <> null) then
                let
                    caps = withCastOrConvert[SQLGetInfo] & [
                        SQLGetInfo = [
                            SQL_SQL_CONFORMANCE = Config_SqlConformance
                        ]
                    ]
                in
                    withCastOrConvert & caps
            else
                withCastOrConvert
    in
        withSqlConformance;

// 
// Load common library functions
// 
Extension.LoadFunction = (name as text) =>
    let
        binary = Extension.Contents(name),
        asText = Text.FromBinary(binary)
    in
        Expression.Evaluate(asText, #shared);

// Diagnostics module contains multiple functions. We can take the ones we need.
Diagnostics = Extension.LoadFunction("Diagnostics.pqm");
Diagnostics.LogValue = if (EnableTraceOutput) then Diagnostics[LogValue] else (prefix, value) => value;

// OdbcConstants contains numeric constants from the ODBC header files, and a 
// helper function to create bitfield values.
ODBC = Extension.LoadFunction("OdbcConstants.pqm");
Odbc.Flags = ODBC[Flags];