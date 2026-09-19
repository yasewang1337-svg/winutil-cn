function Invoke-WPFPanelAutologin {
    <#
    .SYNOPSIS
        Opens Microsoft's Autologon documentation and download page for review.
    #>
    Start-Process 'https://learn.microsoft.com/sysinternals/downloads/autologon' -ErrorAction Stop
}
