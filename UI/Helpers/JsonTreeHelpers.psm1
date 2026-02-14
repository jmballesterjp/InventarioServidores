Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue

function Add-ObjectToTree {
    param(
        [System.Windows.Controls.ItemsControl]$Parent,
        [string]$Name,
        $Value
    )

    $node = New-Object System.Windows.Controls.TreeViewItem

    if ($Value -is [System.Management.Automation.PSCustomObject] -or $Value -is [hashtable]) {
        $node.Header = $Name
        foreach ($p in $Value.PSObject.Properties) {
            Add-ObjectToTree -Parent $node -Name $p.Name -Value $p.Value
        }
    }
    elseif ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $node.Header = "$Name [Array]"
        $i = 0
        foreach ($elem in $Value) {
            Add-ObjectToTree -Parent $node -Name "[$i]" -Value $elem
            $i++
        }
    }
    else {
        $val = if ($null -eq $Value) { '<null>' } else { $Value }
        $node.Header = "$Name: $val"
    }

    $node.IsExpanded = $false
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

Export-ModuleMember -Function Add-ObjectToTree, Populate-TreeViewFromJson, Set-TreeViewItemsExpansion
