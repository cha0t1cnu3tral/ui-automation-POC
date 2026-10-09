$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
[xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Accessibility Exposure Lab - Synthetic Data" Width="520" Height="440"
        WindowStartupLocation="CenterScreen" AutomationProperties.AutomationId="LabWindow">
  <StackPanel Margin="24">
    <TextBlock Text="Accessibility exposure lab" FontSize="22" Margin="0,0,0,12" />
    <TextBlock Text="Synthetic data only. This window is inspected by the lab." TextWrapping="Wrap" />
    <TextBlock Text="Fictional customer: Alex Example" Margin="0,12,0,0"
               AutomationProperties.AutomationId="SyntheticIdentity"
               AutomationProperties.Name="LAB-ONLY identity: Alex Example; email: alex@example.invalid; address: 123 Example Street, Fictional City" />
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
$null = $window.ShowDialog()
