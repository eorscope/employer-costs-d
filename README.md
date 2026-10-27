# eorscope-employer-costs

Dependency-free D package that embeds the EOR Scope dataset of statutory
employer costs, as typed, read-only records.

- 76 countries: employer cost in % and USD per month at an example salary,
  local currency, exchange rate and review date
- 544 employer contribution and statutory extra lines, each with rate, base,
  base factor, floor/ceiling, source URL and date
- 108 declared assumptions (the case each country's total holds for)

Source of the data: the EOR Scope open dataset, https://eorscope.com/data/
(CC BY 4.0).

## Usage

Add the package from its Git repository in `dub.json`:

```json
"dependencies": {
    "eorscope-employer-costs": {
        "repository": "git+https://github.com/eorscope/employer-costs-d.git",
        "version": "v0.1.0"
    }
}
```

```d
import employercosts;

auto de = country("DE");                 // Nullable!CountrySummary
if (!de.isNull)
    writeln(de.get.employerCostPctPrinted);
auto lines = contributions("DE");        // Contribution[]
auto europe = countriesInRegion("Europe");
```

The package is a lookup library: it returns the figures as exported and
computes nothing. Countries flagged `totalDeclaredFloor` publish an "at least"
figure, not a total: read their `employerCostPct` as "at least". Under
`totalDeclaredCeiling` the modelled contribution base is the highest the law
allows and lines with `inTotal` false come on top. A contribution's `rate`
applies to its `base` times `baseFactor` (1 unless the law builds the base from
more than the salary, as Mexico's integrated base does).

For a cost at another salary, use the
[EOR cost calculator](https://eorscope.com/eor-cost-calculator/), which runs
the full computation. How each figure is sourced and checked is set out in the
[methodology](https://eorscope.com/methodology/). Every country has its own
[employer of record page](https://eorscope.com/employer-of-record/) with the
contribution lines and their official sources.

Cost comparison, not legal or tax advice.

## Data version

Export of 13 October 2026 (datapackage.json `created`). SHA-256 of the embedded files:

```
83e1cec0a902ff629be224e22e0c4c11b90adc2f77aaa1e2b2914a79e6075254  data/country_summary.csv
5c55cd63e18a9b8e60813653b600cbe1f0e1bafb560482c949ea5c225900ec85  data/country_contributions.csv
c204bf448d5aecc99968a5e37f71473233cc179b10238d18537e46eb573fd50a  data/country_assumptions.csv
105ff773cdd84d09900a475230ad58a7207718ac9d95b7ec09176a4cb044de01  data/LICENSE
```

## Updating the data

`sync.sh <dir>` copies the three CSV files and the data licence of a dataset
export (https://eorscope.com/data/) into `data/`, where `dub` embeds them at compile time
(`stringImportPaths`). Then run `dub test && dub build`.

## Licence

Code: MIT, see LICENSE.

Data (`data/`): CC BY 4.0, see data/LICENSE. Attribution: EOR Scope,
published by Trésor Kaya EI (Les Créavores), France,
https://eorscope.com/methodology/.
