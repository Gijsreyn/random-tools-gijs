# Microsoft DSC: Parameters and Variables Demo
# This demo shows how to work with parameters and variables in DSC configuration documents
#
# Run the script to see examples in action, or use Get-Help to see full documentation:
#   Get-Help .\005-dsc-variables-and-parameters.ps1 -Full
#
# Key concepts demonstrated:
# - Parameters: Passed from outside, make configs reusable across environments
# - Variables: Defined within config, computed values and constants
# - Using Microsoft.DSC.Debug/Echo resource for simple demonstrations
# - File-based examples in the examples\ folder

#region Parameters Basics

# Parameters make configurations reusable across different environments
# Let's start with a simple example using registry configuration

# Example 1: Using --parameters with inline JSON
$document = @{
    '$schema'  = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    parameters = @{
        logLevel = @{
            type = 'string'
        }
    }
    resources  = @(
        @{
            name       = 'Application Log Level'
            type       = 'Microsoft.Windows/Registry'
            properties = @{
                keyPath   = 'HKCU\Software\MyApplication'
                valueName = 'LogLevel'
                valueData = @{
                    String = "[parameters('logLevel')]"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

# Apply with inline parameter
$params = @{
    parameters = @{
        logLevel = 'Information'
    }
} | ConvertTo-Json -Compress

dsc config --parameters $params test --input $document

#endregion

#region Parameters with Defaults

# Parameters can have default values
$documentWithDefaults = @{
    '$schema'  = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    parameters = @{
        logLevel = @{
            type         = 'string'
            defaultValue = 'Warning'
        }
        appName  = @{
            type         = 'string'
            defaultValue = 'MyApplication'
        }
    }
    resources  = @(
        @{
            name       = 'Application Log Level with defaults'
            type       = 'Microsoft.Windows/Registry'
            properties = @{
                keyPath   = "HKCU\Software\[parameters('appName')]"
                valueName = 'LogLevel'
                valueData = @{
                    String = "[parameters('logLevel')]"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

# This will use defaults: logLevel=Warning, appName=MyApplication
dsc config test --input $documentWithDefaults

Write-Host "`n=== Example 3: Override one parameter ===" -ForegroundColor Cyan
# Override just one parameter, other uses default
$overrideParams = @{
    parameters = @{
        logLevel = 'Debug'
    }
} | ConvertTo-Json -Compress

dsc config --parameters $overrideParams test --input $documentWithDefaults

#endregion

#region Multiple Parameters

# Working with multiple parameters of different types
$multiParamDocument = @{
    '$schema'  = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    parameters = @{
        maxSize    = @{
            type = 'int'
        }
        enabled    = @{
            type = 'bool'
        }
        serverName = @{
            type = 'string'
        }
    }
    resources  = @(
        @{
            name       = 'Configure with multiple parameters'
            type       = 'Microsoft.Windows/Registry'
            properties = @{
                keyPath   = "HKCU\Software\[parameters('serverName')]"
                valueName = 'MaxSize'
                valueData = @{
                    Dword = "[parameters('maxSize')]"
                }
            }
        }
        @{
            name       = 'Enable feature'
            type       = 'Microsoft.Windows/Registry'
            properties = @{
                keyPath   = "HKCU\Software\[parameters('serverName')]"
                valueName = 'Enabled'
                valueData = @{
                    Dword = "[if(parameters('enabled'), 1, 0)]"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

$multiParams = @{
    parameters = @{
        maxSize    = 1024
        enabled    = $true
        serverName = 'WebServer01'
    }
} | ConvertTo-Json -Compress

dsc config --parameters $multiParams test --input $multiParamDocument

#endregion

#region Parameters from File

# In real scenarios, use parameter files for better organization
dsc config --parameters-file .\examples\app-config.dsc.config.parameters.yaml get --file .\examples\app-config.dsc.config.yaml

#endregion

#region Array Parameters

# Parameters can be arrays - useful for lists of items
$arrayParamDocument = @{
    '$schema'  = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    parameters = @{
        adminUsers = @{
            type = 'array'
        }
    }
    resources  = @(
        @{
            name       = 'Store admin users'
            type       = 'Microsoft.Windows/Registry'
            properties = @{
                keyPath   = 'HKCU\Software\AdminConfig'
                valueName = 'Administrators'
                valueData = @{
                    String = "[join(parameters('adminUsers'), ';')]"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

Write-Host "`n=== Example 6: Array parameters ===" -ForegroundColor Cyan
$arrayParams = @{
    parameters = @{
        adminUsers = @('Admin1', 'Admin2', 'Admin3')
    }
} | ConvertTo-Json -Compress

dsc config --parameters $arrayParams test --input $arrayParamDocument

#endregion

#region Variables Basics
# Example 1: Basic variables with Echo resource
$variablesDocument = @{
    '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    variables = @{
        greeting    = 'Hello from DSC'
        environment = 'Development'
        timestamp   = '2026-02-01'
    }
    resources = @(
        @{
            name       = 'Echo greeting'
            type       = 'Microsoft.DSC.Debug/Echo'
            properties = @{
                output = "[variables('greeting')]"
            }
        }
        @{
            name       = 'Echo environment'
            type       = 'Microsoft.DSC.Debug/Echo'
            properties = @{
                output = "[concat('Running in ', variables('environment'), ' environment')]"
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

dsc config get --input $variablesDocument

#endregion

#region Variables with Functions

# Variables can use DSC functions
$variablesWithFunctions = @{
    '$schema' = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    variables = @{
        firstName  = 'John'
        lastName   = 'Doe'
        fullName   = "[concat(variables('firstName'), ' ', variables('lastName'))]"
        servers    = @('web01', 'web02', 'web03')
    }
    resources = @(
        @{
            name       = 'Echo full name'
            type       = 'Microsoft.DSC.Debug/Echo'
            properties = @{
                output = "[concat('Full name: ', variables('fullName'))]"
            }
        }
        @{
            name       = 'Echo server list'
            type       = 'Microsoft.DSC.Debug/Echo'
            properties = @{
                output = "[concat('Servers: ', join(variables('servers'), ', '))]"
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress
dsc config get --input $variablesWithFunctions

#endregion

#region Variables and parameters together

# You can use both variables and parameters together
# This is useful because:
# - Parameters let you pass in environment-specific values (Dev, Test, Prod)
# - Variables compute derived values based on those parameters
# - This keeps your configuration DRY (Don't Repeat Yourself)
# - You define logic once in variables, then reuse it across multiple resources
$combinedDocument = @{
    '$schema'  = 'https://aka.ms/dsc/schemas/v3/bundled/config/document.json'
    parameters = @{
        environment = @{
            type = 'string'
        }
    }
    variables  = @{
        appName   = 'MyApp'
        prefix    = "[concat(variables('appName'), '-', parameters('environment'))]"
        isProduction = "[if(equals(parameters('environment'), 'Production'), 'Yes', 'No')]"
    }
    resources  = @(
        @{
            name       = 'Echo configuration'
            type       = 'Microsoft.DSC.Debug/Echo'
            properties = @{
                output = "[concat('Prefix: ', variables('prefix'), ' | Is Production: ', variables('isProduction'))]"
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress
$envParams = @{
    parameters = @{
        environment = 'Production'
    }
} | ConvertTo-Json -Compress

dsc config --parameters $envParams get --input $combinedDocument

$envParamsDev = @{
    parameters = @{
        environment = 'Development'
    }
} | ConvertTo-Json -Compress
dsc config --parameters $envParamsDev get --input $combinedDocument

#endregion Variables and parameters together

