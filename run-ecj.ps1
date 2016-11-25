pushd "C:\Users\helmi\Google Drive\Bio-inspired\CW2\ecj"

# This script has been designed with the aim to provide a quick method to automate the running of ECJ experiments and the subsequent data collection. It was not designed for more in depth analysis and is more suited for quick experiment work. For example, mistyping the parameters in the beggining can lead to errors.
# Note this script will not work if the paths to the ecj and output directories have not been set up properly.

# Clear variables that will be in use
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0

# Print to terminal
# Write-Host "sextic_regression experiment"
do {$problem = Read-Host -Prompt "sextic_regression or santa_fe_ant (exact entries only)"}
 until ( ($problem -match "sextic_regression") -or ($problem -match "santa_fe_ant") )

# Prompts the user for the name of the experiment. Used to automatically generate a folder to store the results.
$experiment = Read-Host -Prompt "Name of experiment"
$output_path = "C:\Users\helmi\Google Drive\Bio-inspired\CW2\output\${problem}\${experiment}"

New-Item "$output_path" -type directory -force >$null

# Prompts the user for the desired parameters of the experiment
do {$runs = Read-Host -Prompt "Enter the number of runs"}
 until (($runs -ge 0))

do {$generations = Read-Host -Prompt "Enter the number of generations (default 50)"}
until (($generations -ge 0))

do {$population = Read-Host -Prompt "Enter the number of the population (default 100)"}
until (($population -ge 0))

${use_elitism} = 0
do {$elite = Read-Host -Prompt "Elitism? (default 1)"}
until (($elite -ge 0))

do {$parents = Read-Host -Prompt "Enter tournament size (default 7)"}
until (($parents -ge 0))

do {$depth_constraint = Read-Host -Prompt "Enter depth constraint (default is 17)"}
until (($depth_constraint -ge 0))

# Generates a text file to store the best outputs of each run. Further data is extracted from this file.
New-Item "$output_path/collected_${experiment}_output.txt" -type file -force -value "Results over ${runs} runs `n" >$null

Write-Host "Starting evolution:-"

# For the number of desired runs, run the sextic_regression problem with the provided user defined parameters
For($i = 0; $i -lt ${runs}; $i++){
    java -cp . ec.Evolve -file cw2/${problem}.params -p generations=$generations -p pop.subpop.0.size=$population -p breed.elite.${use_elitism} = $elite -p select.tournament.size = $parents -p gp.koza.mutate.maxdepth = $depth_constraint -p gp.koza.xover.maxdepth = $depth_constraint >$null
    # Copy the results of this run and rename it accordingly. Used to keep track of which results belong to which run.
    Copy-Item out.stat "$output_path/out_${experiment}-${i}.txt"
    Write-Host "Finished ${i}..."
}

Write-Host "Completed evolution"

# For every run of the problem: read the output file, extract the best result, append it to the collected output text file. The reason for a separate for loop is because "file in use" conflicts can arise.
For($i = 0; $i -lt ${runs}; $i++){
    Write-Host "Extracting ${i}..."
    $result = Select-String -Path "$output_path/out_${experiment}-${i}.txt" -Pattern "Best Individual of Run:" -Context 0,3
    Add-Content "$output_path/collected_${experiment}_output.txt" "`n${result}"

}

# Defines a patten to recognize and searches the collected output text file for every instance of that pattern. Saves the result to another text file. This file is the final results file containing the best fitnesses.
$regex = "Fitness: Standardized=\b\d{1,3}\.\d{1,20}\b Adjusted=\b\d{1,3}\.\d{1,20}\b Hits=\b\d{1,3}\b"
Select-String -Path "$output_path/collected_${experiment}_output.txt" -Pattern "$regex" | % { $_.Matches } | % { $_.Value } > "$output_path/fitnesses_${experiment}_output.txt"

# Defines variables used to store fitness values and perform calculations
$standardized = @(0 .. ${runs})
$adjusted = @(0 .. ${runs})
$best_standardized = [double]::PositiveInfinity
$best_adjusted = [double]::NegativeInfinity
$worst_standardized = [double]::NegativeInfinity
$worst_adjusted = [double]::PositiveInfinity

# For every run of the problem, extract the standardized and adjusted fitness values and store them in an array. Also saves the best and worst of each experiment.
For($i = 0; $i -lt ${runs}; $i++){
    if (${i} -eq 0) {
      (get-content "$output_path/fitnesses_${experiment}_output.txt" -Head 1) | % { 
        if ($_ -match "Standardized=(\b\d{1,3}\.\d{1,20}\b)") { 
            $standardized[${i}] = [double]$matches[1]

        }

        if ($_ -match "Adjusted=(\b\d{1,3}\.\d{1,20}\b)") { 
            $adjusted[${i}] = [double]$matches[1]
        }

        }
    }

    else {
    (get-content "$output_path/fitnesses_${experiment}_output.txt" -totalcount (${i}+1))[-1] | % { 
        if ($_ -match "Standardized=(\b\d{1,3}\.\d{1,20}\b)") { 
            $standardized[${i}] = [double]$matches[1]
        }

        if ($_ -match "Adjusted=(\b\d{1,3}\.\d{1,20}\b)") { 
            $adjusted[${i}] = [double]$matches[1]
        }

    } 

    }

    if ($standardized[${i}] -lt $best_standardized) {
        $best_standardized = $standardized[${i}]
        $count_bs = ${i}
    }

    if ($adjusted[${i}] -gt $best_adjusted) {
        $best_adjusted = $adjusted[${i}]
        $count_ba = ${i}
    }

    if ($standardized[${i}] -gt $worst_standardized) {
        $worst_standardized = $standardized[${i}]
        $count_ws = ${i}
    }

    if ($adjusted[${i}] -lt $worst_adjusted) {
        $worst_adjusted = $adjusted[${i}]
        $count_wa = ${i}
    }

    # Sums the fitness values. Used for mean calculations.

    $standard_tot = $standard_tot + $standardized[$i] 
    $adjusted_tot = $adjusted_tot + $adjusted[$i]   

}

# Calculates the standardized and adjusted mean values
$standard_mean = ${standard_tot}/${runs}
$adjusted_mean = ${adjusted_tot}/${runs}

# Calculate standard deviations for each experiment
$sum = 0

For($i = 0; $i -lt ${runs}; $i++){

    $k = $standardized[${i}] - $standard_mean
    $sum_standard = $sum_standard + [math]::pow($k, 2)

    $k2 = $adjusted[${i}] - $adjusted_mean
    $sum_adjusted = $sum_adjusted + [math]::pow($k2, 2)


}

$sigma_standard = [math]::sqrt( (${sum_standard}/${runs}) )
$sigma_adjusted = [math]::sqrt( (${sum_adjusted}/${runs}) )

# Appends the parameters of the experiment as well as the result of calculations to the final output text file. Used for analysis.

Add-Content "$output_path/fitnesses_${experiment}_output.txt" "`nExperiment: ${experiment}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "---"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Best Standardized Fitness: ${best_standardized}, Run: ${count_bs}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Best Adjusted Fitness: ${best_adjusted}, Run: ${count_ba}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "---"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Worst Standardized Fitness: ${worst_standardized}, Run: ${count_ws}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Worst Adjusted Fitness: ${worst_adjusted}, Run: ${count_wa}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "---"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Mean Standardized best Fitness ${standard_mean}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Mean Adjusted best Fitness ${adjusted_mean}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "---"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Std. Dev. of Standardized Fitnesses ${sigma_standard}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Std. Dev. of Adjusted Fitnesses ${sigma_adjusted}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "---"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "`nGenerations: ${generations}, Population: ${population}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Elitism: ${use_elitism}, Size: ${elite}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "Tournament size: ${parents}, Depth constraints: ${depth_constraint}"
Add-Content "$output_path/fitnesses_${experiment}_output.txt" "`nRun count: ${runs}"

Write-Host "`nMean Standardized best fitness " $standard_mean " over ${runs} runs"
Write-Host "Mean Adjusted best fitness " $adjusted_mean " over ${runs} runs"
Write-Host "`nStd. Dev. of Standardized Fitnesses ${sigma_standard}"
Write-Host "Std. Dev. of Adjusted Fitnesses ${sigma_adjusted}"

Write-Host "`nExperiment using ${generations} generations, with population of ${population}"

# Beeps when the experiment is finished
[console]::beep(500,300)
[console]::beep(750,750)

popd