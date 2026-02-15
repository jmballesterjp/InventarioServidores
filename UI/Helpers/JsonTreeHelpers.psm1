Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue

function Add-ObjectToTree {
    param(
        [System.Windows.Controls.ItemsControl]$Parent,
        [string]$Name,
        $Value,
        [System.Collections.Generic.HashSet[object]]$VisitedObjects
    )

    # Inicializar HashSet para detectar ciclos en la primera llamada
    if ($null -eq $VisitedObjects) {
        $VisitedObjects = New-Object 'System.Collections.Generic.HashSet[object]'
    }

    $node = New-Object System.Windows.Controls.TreeViewItem

    # Detectar ciclos: si el objeto ya fue visitado, evitar recursión infinita
    if ($null -ne $Value -and $Value -is [object] -and -not ($Value -is [ValueType]) -and -not ($Value -is [string])) {
        if ($VisitedObjects.Contains($Value)) {
            $node.Header = "$Name`: <circular reference>"
            $node.IsExpanded = $false
            $Parent.Items.Add($node)
            return
        }
        # Marcar como visitado
        [void]$VisitedObjects.Add($Value)
    }

    # Tipos primitivos que deben tratarse como valores simples
    $primitiveTypes = @(
        [int], [long], [double], [float], [decimal], [byte], [bool],
        [DateTime], [DateTimeOffset], [TimeSpan], [Guid], [string]
    )

    $isPrimitive = $false
    foreach ($type in $primitiveTypes) {
        if ($Value -is $type) {
            $isPrimitive = $true
            break
        }
    }

    # Si es null o primitivo, tratar como valor simple
    if ($null -eq $Value -or $isPrimitive) {
        $val = if ($null -eq $Value) { '<null>' } else { $Value }
        $node.Header = "$Name`: $val"
    }
    # Tratar arrays antes que objetos
    elseif ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string]) -and -not ($Value -is [System.Collections.IDictionary])) {
        $node.Header = "$Name [Array]"
        $i = 0
        foreach ($elem in $Value) {
            Add-ObjectToTree -Parent $node -Name "[$i]" -Value $elem -VisitedObjects $VisitedObjects
            $i++
        }
    }
    # Tratar Hashtables y Dictionaries
    elseif ($Value -is [System.Collections.IDictionary]) {
        $node.Header = $Name
        foreach ($key in $Value.Keys) {
            Add-ObjectToTree -Parent $node -Name $key -Value $Value[$key] -VisitedObjects $VisitedObjects
        }
    }
    # Objetos complejos (PSCustomObject, etc.)
    elseif ($Value.PSObject.Properties.Count -gt 0) {
        $node.Header = $Name
        # Filtrar solo propiedades que son datos (excluir métodos y propiedades del sistema)
        $dataProperties = $Value.PSObject.Properties | Where-Object {
            $_.MemberType -eq 'NoteProperty' -or
            $_.MemberType -eq 'Property' -or
            $_.MemberType -eq 'ScriptProperty'
        }

        foreach ($p in $dataProperties) {
            Add-ObjectToTree -Parent $node -Name $p.Name -Value $p.Value -VisitedObjects $VisitedObjects
        }
    }
    else {
        # Valor simple por defecto
        $val = if ($null -eq $Value) { '<null>' } else { $Value.ToString() }
        $node.Header = "$Name`: $val"
    }

    # Expandir el nodo root por defecto, el resto colapsados
    $node.IsExpanded = ($Name -eq 'root')
    $Parent.Items.Add($node)
}

function Populate-TreeViewFromJson {
    param(
        [System.Windows.Controls.TreeView]$TreeView,
        [string]$JsonText
    )

    $TreeView.Items.Clear()
    try {
        $obj = $JsonText | ConvertFrom-Json -Depth 100
    }
    catch {
        $obj = $null
    }

    if ($null -eq $obj) { return }
    Add-ObjectToTree -Parent $TreeView -Name 'root' -Value $obj
}

# Popula directamente desde un objeto PowerShell (sin serializar a JSON)
function Populate-TreeViewFromObject {
    param(
        [System.Windows.Controls.TreeView]$TreeView,
        $Object
    )

    $TreeView.Items.Clear()
    if ($null -eq $Object) { return }
    Add-ObjectToTree -Parent $TreeView -Name 'root' -Value $Object
    # write-host "p" -ForegroundColor Green
}

function Set-TreeViewItemsExpansion {
    param(
        [System.Windows.Controls.ItemsControl]$parent,
        [bool]$expanded
    )

    foreach ($item in $parent.Items) {
        if ($item -is [System.Windows.Controls.TreeViewItem]) {
            $item.IsExpanded = $expanded
            if ($item.Items.Count -gt 0) {
                Set-TreeViewItemsExpansion -parent $item -expanded $expanded
            }
        }
    }
}

Export-ModuleMember -Function Add-ObjectToTree, Populate-TreeViewFromJson, Populate-TreeViewFromObject, Set-TreeViewItemsExpansion
