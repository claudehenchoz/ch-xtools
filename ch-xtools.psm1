function Measure-100Commands ($command) {
    # Runs a command 100 times and measures the time it takes to execute it
    1..100 | foreach {Measure-Command -Expression {Invoke-Expression $command}} |
             Measure-Object -Property TotalMilliseconds -Average
}
