#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#Model Development from GAMS
#                             DEL
#                                   Version Control: v.11.09.2023
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Import packages
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
using JuMP
using HiGHS
using DataFrames
using XLSX

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# Declare Model
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
Model_m = Model(HiGHS.Optimizer)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#Declare Sets
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
###Input set list inputs from spreadsheet
Sets_Inputs_Raw = DataFrame(XLSX.readtable("InputData_WorkingCopy.xlsm", "Set List")...)

Year = filter!(!ismissing, (Sets_Inputs_Raw[:, "Year"]))
Season = filter!(!ismissing, (Sets_Inputs_Raw[:, "Season"]))
Time = filter!(!ismissing, (Sets_Inputs_Raw[:, "Time"]))

Scenario = filter!(!ismissing, (Sets_Inputs_Raw[:, "Scenario"]))

Country = filter!(!ismissing, (Sets_Inputs_Raw[:, "Country"]))
Region = filter!(!ismissing, (Sets_Inputs_Raw[:, "Region"]))
Area = filter!(!ismissing, (Sets_Inputs_Raw[:, "Area"]))

Fuel = filter!(!ismissing, (Sets_Inputs_Raw[:, "Fuel"]))
Technology = filter!(!ismissing, (Sets_Inputs_Raw[:, "Technology"]))

Direction = filter!(!ismissing, (Sets_Inputs_Raw[:, "Direction"]))

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#Declare Parameters
 #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
CarrierMix = DataFrame(XLSX.readtable("InputData_WorkingCopy.xlsm", "CarrierMix"; first_row=20)...)


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#Declare Variables
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
@variable(Model_m, 0<=vTotalFuelUse[tech in 1:length(Technology), c in 1:length(Country), r in 1:length(Region), a in 1:length(Area), sc in 1:length(Scenario), y in 1:length(Year), s in 1:length(Season), t in 1:length(Time)]);
@variable(Model_m, 0<=vSpecificFuelUse[tech in 1:length(Technology), c in 1:length(Country), r in 1:length(Region), a in 1:length(Area), f in 1:length(Fuel), sc in 1:length(Scenario), y in 1:length(Year), s in 1:length(Season), t in 1:length(Time)]);

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#Declare Constraints
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
#Formation of a data based conditional constraint.
#Based on the exogenously defined input data, apply constraint only to combinations of sets that have data. Otherwise do nothing.
for tech in 1:length(Technology)
    #Columns
    column_name = Technology[tech]
        #Rows
        for f in 1:length(Fuel)
            try
                row_filter = filter(row -> row.Direction == "Input" && row.Fuel == Fuel[f], CarrierMix) ##Filters only the row which connects the current 2 indices
                if !isempty(row_filter)
                   value = row_filter[!, column_name][1] ##Filtering out the only instance that matches the 3 given set instances. Practically an INDEX/MATCH or LOOKUP in the dataset which can only return a single unique value.
                   if !ismissing(value) && !isempty(value) ##Checks if the combination doesn't exist, and also if the target indices lead to a "missing" value from the input side. If so, abort loop.    
                        for c in 1:length(Country), r in 1:length(Region), a in 1:length(Area), sc in 1:length(Scenario), y in 1:length(Year), s in 1:length(Season), t in 1:length(Time) #Residual variable related sets for constraint formation.

                            @constraint(Model_m, 
                            vSpecificFuelUse[tech, c, r, a, f, sc, y, s, t]
                            ==
                            value
                            *
                            vTotalFuelUse[tech, c, r, a, sc, y, s, t]
                            )

                        end
                    end
                end
            catch e #If a model error occurs due to absence of matching sets, abort the constraint. Then pass on to the next combination of set indices and form only necessary constraints.
               if isa(e, ArgumentError)
               elseif isa(e, KeyError)
               else
                  rethrow()
               end
            end
        end
end

print(Model_m) #Print constraints.


