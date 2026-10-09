param([switch]$Hardened)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
[xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Accessibility Exposure Lab - Synthetic Data" Width="560" Height="560"
        WindowStartupLocation="CenterScreen" AutomationProperties.AutomationId="LabWindow">
  <StackPanel Margin="24">
    <TextBlock Text="Accessibility exposure lab" FontSize="22" Margin="0,0,0,12" />
    <TextBlock Text="Synthetic data only. This window is inspected by the lab." TextWrapping="Wrap" />
    <TextBlock x:Name="IdentityLabel" Text="Fictional customer: Alex Example" Margin="0,12,0,0"
               AutomationProperties.AutomationId="SyntheticIdentity"
               AutomationProperties.Name="LAB-ONLY identity: Alex Example; email: alex@example.invalid; address: 123 Example Street, Fictional City" />
    <TextBlock x:Name="MaskedLabel" Text="Email: a***@example.invalid" Margin="0,12,0,0"
               AutomationProperties.AutomationId="MaskedIdentity"
               AutomationProperties.Name="LAB-ONLY masked identity: alex@example.invalid" />
    <TextBlock Text="Disabled fictional customer field" Margin="0,12,0,4" />
    <TextBox x:Name="DisabledIdentity" Text="Customer details unavailable" IsEnabled="False"
             AutomationProperties.AutomationId="DisabledIdentity"
             AutomationProperties.Name="LAB-ONLY disabled identity: Alex Example, 123 Example Street" />
    <TextBlock Text="Demo account" Margin="0,16,0,4" />
    <TextBox Text="demo-user@example.invalid" AutomationProperties.Name="Synthetic account"
             AutomationProperties.AutomationId="DemoAccount" />
    <TextBlock Text="Demo password (never collected)" Margin="0,12,0,4" />
    <PasswordBox AutomationProperties.Name="Synthetic password"
                 AutomationProperties.AutomationId="DemoPassword" />
    <CheckBox Content="Synthetic preference" Margin="0,12,0,8"
              AutomationProperties.AutomationId="DemoPreference" />
    <Button Content="Demo action" AutomationProperties.AutomationId="DemoAction" />
  </StackPanel>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $markup
$window = [Windows.Markup.XamlReader]::Load($reader)
if ($Hardened) {
    [Windows.Automation.AutomationProperties]::SetName($window.FindName('IdentityLabel'), 'Fictional customer: Alex Example')
    [Windows.Automation.AutomationProperties]::SetName($window.FindName('MaskedLabel'), 'Email: a***@example.invalid')
    [Windows.Automation.AutomationProperties]::SetName($window.FindName('DisabledIdentity'), 'Customer details unavailable')
}
$null = $window.ShowDialog()
