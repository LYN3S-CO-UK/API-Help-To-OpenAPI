param (
    [string]$OutputFilePath = "./openapi.json", 
    # The file path where the generated OpenAPI JSON will be saved.
    
    [string]$BaseUrl = "https://localhost:44347/"
    # The base URL of the API help documentation.
)

function Remove-InvalidXmlCharacters {
    param (
        [string]$content
    )
    # Define a list of invalid characters or patterns
    $invalidPatterns = @('&Copy;', '&nbsp;', '&reg;', '&trade;')

    foreach ($pattern in $invalidPatterns) {
        $content = $content -replace [regex]::Escape($pattern), ''
    }

    return $content
}

# Try accessing the base URL first
try {
    $response = Invoke-WebRequest -Uri $baseUrl -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Output "Base URL is accessible."
    }
} catch {
    Write-Output "Base URL is not accessible."
    exit
}

#Clean BaseURL
$BaseUrl = $BaseUrl.TrimEnd('/')

# Download the content from the help URL and load it into memory
$response = Invoke-WebRequest -Uri "$BaseUrl/help"
$content = Remove-InvalidXmlCharacters -content $response.Content
[xml]$xmlContent = $content

# Extract the title from the H1 field on the first page
$h1Node = $xmlContent.SelectSingleNode("//h1")
$hrefNode = $xmlContent.SelectSingleNode("//a[@class='navbar-brand' and @href='/']")

if ($hrefNode) {
    $title = $hrefNode.InnerText
} elseif ($h1Node) {
    $title = $h1Node.InnerText
} else {
    $title = "Default Title"
}

# Define the OpenAPI JSON structure
$openApi = @{
    openapi = "3.0.0"
    info = @{
        title = $title
        description = "Converted from $baseUrl/help"
        version = "1.0.0"
    }
    servers = @(
        @{
            url = $baseUrl
        }
    )
    paths = @{}
    tags = @()
}

# Add security requirements if authentication is required
    $openApi.security = @(
        @{
            bearerAuth = @()
        }
    )
    $openApi.components = @{
        securitySchemes = @{
            bearerAuth = @{
                type = "http"
                scheme = "bearer"
            }
        }
    }

# Parse the XML content and populate the OpenAPI paths
foreach ($section in $xmlContent.SelectNodes("//h2")) {
    $tagName = $section.InnerText
    $descriptionNode = $section.SelectSingleNode("following-sibling::p[1]")
    
    if ($null -ne $descriptionNode) {
        $description = $descriptionNode.InnerText.Trim()
    } else {
        $description = ""
    }

    if ($description) {
        $openApi.tags += @{
            name = $tagName
            description = $description
        }
    } else {
        $openApi.tags += @{
            name = $tagName
        }
    }

    foreach ($api in $section.SelectNodes("following-sibling::table[1]//tr")) {
        $apiNameNode = $api.SelectSingleNode("td[@class='api-name']/a")
        $apiDescriptionNode = $api.SelectSingleNode("td[@class='api-documentation']/p")

        if ($apiNameNode -and $apiDescriptionNode) {
            $apiName = $apiNameNode.InnerText
            $apiDescription = $apiDescriptionNode.InnerText

            $method = $apiName.Split(" ")[0]
            $path = "/" + $apiName.Split(" ")[1]

            # Remove query strings from paths
            if ($path -match "\?(.*)") {
                $queryString = $matches[1]
                $path = $path.Split("?")[0]
                $queryParams = @()

                foreach ($param in $queryString.Split("&")) {
                    $paramName = $param.Split("=")[0].Trim("{}")
                    $queryParams += @{
                        name = $paramName
                        in = "query"
                        required = $true
                        schema = @{
                            type = "string"
                        }
                    }
                }
            }

            # Navigate to the href to get additional data
            $href = $apiNameNode.Attributes["href"].Value
            $apiUrl = [System.Uri]::new([System.Uri]::new($baseUrl), $href).AbsoluteUri
            $apiResponse = Invoke-WebRequest -Uri $apiUrl
            $APIcontent = Remove-InvalidXmlCharacters -content $apiResponse.Content
            [xml]$apiXmlContent = $APIcontent 

            # Extract additional data from the API page
            $requestInfo = $apiXmlContent.SelectSingleNode("//h2[.='Request Information']/following-sibling::p[1]").InnerText
            $responseInfo = $apiXmlContent.SelectSingleNode("//h2[.='Response Information']/following-sibling::p[1]").InnerText

            # Extract parameters from the API page
            $parameters = @()
            foreach ($param in $apiXmlContent.SelectNodes("//h3[.='Body Parameters']/following-sibling::table[1]//tr")) {
                $paramNameNode = $param.SelectSingleNode("td[@class='parameter-name']")
                $paramTypeNode = $param.SelectSingleNode("td[@class='parameter-type']")
                $paramRequiredNode = $param.SelectSingleNode("td[@class='parameter-annotations']")

                if ($paramNameNode -and $paramTypeNode -and $paramRequiredNode) {
                    $paramName = $paramNameNode.InnerText
                    $paramType = $paramTypeNode.InnerText.Trim().ToLower()
                    $paramRequired = $paramRequiredNode.InnerText -match "Required"

                    # Ensure param_type is one of the allowed values
                    if ($paramType -notin @("array", "boolean", "integer", "number", "object", "string")) {
                        $paramType = "string"
                    }

                    $parameters += @{
                        name = $paramName
                        in = "query"  # Default to query for now
                        required = $paramRequired
                        schema = @{
                            type = $paramType
                        }
                    }
                }
            }

            if (-not $openApi.paths.ContainsKey($path)) {
                $openApi.paths[$path] = @{}
            }

            $operation = @{
                summary = $apiDescription
                tags = @($tagName)
                responses = @{
                    "200" = @{
                        description = if ($responseInfo) { $responseInfo } else { "Successful response" }
                    }
                }
            }

            # Add parameters only for non-GET operations
            if ($method -ne "GET") {
                $operation.parameters = $parameters

                # Add requestBody only for non-GET operations with request info
                if ($requestInfo) {
                    $operation.requestBody = @{
                        description = $requestInfo
                        content = @{
                            "application/json" = @{
                                schema = @{
                                    type = "object"
                                    properties = @{}
                                }
                            }
                        }
                    }

                    foreach ($param in $parameters) {
                        $operation.requestBody.content."application/json".schema.properties[$param.name] = @{
                            type = $param.schema.type
                        }
                    }
                }
            }

            # Check for path parameters and define them at the operation level
            $pathParams = @()
            if ($path -match "{(.*?)}") {
                foreach ($param in [regex]::Matches($path, "{(.*?)}")) {
                    $pathParams += @{
                        name = $param.Groups[1].Value
                        in = "path"
                        required = $true
                        schema = @{
                            type = "string"
                        }
                    }
                }
            }

            if ($pathParams) {
                $operation.parameters += $pathParams
            }

            # Ensure sibling parameters have unique name + in values
            $uniqueParams = @{}
            foreach ($param in $operation.parameters) {
                $key = "$($param.name)-$($param.in)"
                if (-not $uniqueParams.ContainsKey($key)) {
                    $uniqueParams[$key] = $param
                }
            }
            $operation.parameters = $uniqueParams.Values

            $openApi.paths[$path][$method.ToLower()] = $operation
        }
    }
}

# Convert the OpenAPI structure to JSON and output it in UTF-8 format
$openApiJson = $openApi | ConvertTo-Json -Depth 100 
[System.IO.File]::WriteAllText($outputFilePath, $openApiJson, [System.Text.Encoding]::UTF8)

Write-Output "OpenAPI JSON file created at $outputFilePath"