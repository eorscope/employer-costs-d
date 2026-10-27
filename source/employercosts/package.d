/**
 * The EOR Scope dataset of statutory employer costs (76 countries), embedded
 * at compile time and exposed as typed, read-only records. No dependencies, no network calls.
 *
 * The package is a lookup library: it returns the figures as exported and
 * computes nothing. Employer cost totals are the ones published in the
 * dataset; the package does not recompute them. For a cost at another salary,
 * use the calculator at https://eorscope.com/eor-cost-calculator/.
 *
 * $(UL
 * $(LI $(LREF countries), $(LREF country) and $(LREF countriesInRegion)
 *      return one record per country.)
 * $(LI $(LREF contributions) returns the employer contributions and statutory
 *      extras of a country.)
 * $(LI $(LREF assumptions) returns the case each country's lines and total
 *      hold for.)
 * )
 *
 * A country flagged `totalDeclaredFloor` publishes an "at least" figure, not
 * a total. Under `totalDeclaredCeiling` the modelled contribution base is the
 * highest the law allows, and lines with `inTotal` false come on top. A
 * contribution's `rate` applies to its `base` times `baseFactor` (1 unless the
 * law builds the base from more than the salary, as Mexico's integrated base
 * does), before `baseFloorAnnualLocal` and `baseCapAnnualLocal`.
 *
 * Sources and method: https://eorscope.com/methodology/. Each country has a
 * page under https://eorscope.com/employer-of-record/ with its sources. The
 * figures are a cost comparison, not legal or tax advice.
 *
 * License: code MIT; embedded data (`data/`) CC BY 4.0
 * (https://creativecommons.org/licenses/by/4.0/). Attribution: EOR Scope,
 * published by Trésor Kaya EI (Les Créavores), France.
 */
module employercosts;

import std.algorithm : canFind, filter, map, sort, uniq;
import std.array : array, split;
import std.conv : to;
import std.datetime.date : Date;
import std.string : strip, toUpper;
import std.typecons : Nullable;
import std.uni : sicmp;

/// One row of country_summary.csv. Optional numbers and dates are null when
/// the dataset leaves them empty.
struct CountrySummary
{
    string iso;                         /// ISO 3166-1 alpha-2
    string name;                        /// country name
    string region;                      /// region, see $(LREF regions)
    string currency;                    /// ISO 4217 local currency
    int exampleSalaryUSD;               /// illustrative gross annual salary in USD (an example, not a median)
    string exampleRole;                 /// illustrative role
    string examplePlace;                /// state, province or city the lines are priced for, when not national
    Nullable!double basicShareOfGross;  /// share of gross taken as basic pay by lines with base "basic"
    double employerCostPct;             /// statutory employer cost, percent of gross at the example salary
    double employerCostPctPrinted;      /// the same percent as printed on eorscope.com (1 decimal)
    bool totalDeclaredFloor;            /// the employer cost is an "at least" figure, not a total
    bool totalDeclaredCeiling;          /// the modelled base is the highest the law allows; lines with inTotal false come on top
    double employerCostUSDMonth;        /// statutory employer cost per month in USD at the example salary
    string totalExcludes;               /// a cost the total leaves out
    double fxLocalPerUSD;               /// local currency units per 1 USD used for the conversion
    Nullable!Date fxDate;               /// date of the exchange rate (null for USD)
    Nullable!Date lastReviewed;         /// date the country data was last verified
}

/// One row of country_contributions.csv: an employer contribution (lineType
/// "contribution") or a statutory extra (lineType "statutory_extra").
struct Contribution
{
    string iso;                               ///
    string country;                           ///
    string currency;                          ///
    string lineType;                          /// contribution | statutory_extra
    string lineID;                            /// unique within the country and line type
    string lineName;                          ///
    Nullable!double rate;                     /// decimal (0.12 = 12 %); null for statutory extras
    string base;                              /// gross | basic | flat | band | "" (statutory extras)
    Nullable!double baseFactor;               /// multiplier on the base, applied before floor and cap (1 = the salary itself); null for flat lines and statutory extras
    Nullable!double baseFloorAnnualLocal;     /// yearly floor on the base, local currency
    Nullable!double baseCapAnnualLocal;       /// yearly ceiling on the base, local currency
    Nullable!double flatAnnualLocal;          /// fixed yearly amount when base is "flat"
    Nullable!double minGrossAnnualLocal;      /// line applies only when annual gross is at least this
    Nullable!double maxGrossAnnualLocal;      /// line applies only when annual gross is at most this
    string extraKind;                         /// percent | months | days | "" (contributions)
    Nullable!double extraValue;               /// value in the unit given by extraKind
    bool secondarySource;                     /// the line rests, in whole or in part, on a non-official source
    bool thirteenthMonth;                     /// the country mandates a 13th-month salary
    bool totalDeclaredFloor;                  /// the country's employer cost is an "at least" figure
    bool totalDeclaredCeiling;                /// the modelled base is the highest the law allows
    bool inTotal;                             /// the line is included in the employer cost total
    string applies;                           /// condition in plain words
    string notes;                             ///
    string sourceName;                        ///
    string sourceURL;                         ///
    Nullable!Date sourceCheckedAt;            ///
}

/// One row of country_assumptions.csv: the case a country's lines and total
/// are priced for.
struct Assumption
{
    string iso;    ///
    string id;     /// unique within the country
    string label;  ///
    double value;  /// a share, a rate, a threshold, or 1 for a stated condition
    string notes;  ///
}

/// Every country, sorted by ISO code.
CountrySummary[] countries()
{
    return data().countries.dup;
}

/// The country with the given ISO 3166-1 alpha-2 code (case-insensitive), or
/// null.
Nullable!CountrySummary country(string iso)
{
    iso = iso.toUpper;
    foreach (c; data().countries)
        if (c.iso == iso)
            return Nullable!CountrySummary(c);
    return Nullable!CountrySummary.init;
}

/// The distinct regions, sorted.
string[] regions()
{
    auto rs = data().countries.map!(c => c.region).array;
    sort(rs);
    return rs.uniq.array;
}

/// The countries of a region (case-insensitive), sorted by ISO code.
CountrySummary[] countriesInRegion(string region)
{
    return data().countries.filter!(c => sicmp(c.region, region) == 0).array;
}

/// The contribution and statutory extra lines of a country, in dataset order;
/// empty for an unknown code.
Contribution[] contributions(string iso)
{
    if (auto p = iso.toUpper in data().contributions)
        return (*p).dup;
    return null;
}

/// The declared assumptions of a country, in dataset order.
Assumption[] assumptions(string iso)
{
    if (auto p = iso.toUpper in data().assumptions)
        return (*p).dup;
    return null;
}

// --- embedded data ---

private immutable summaryCsv = import("country_summary.csv");
private immutable contributionsCsv = import("country_contributions.csv");
private immutable assumptionsCsv = import("country_assumptions.csv");

private struct Dataset
{
    CountrySummary[] countries;
    Contribution[][string] contributions;
    Assumption[][string] assumptions;
}

private __gshared Dataset* ds;

private Dataset* data()
{
    import std.concurrency : initOnce;

    return initOnce!ds(load());
}

// --- parsing ---

/// Thrown when an embedded CSV file cannot be read.
class CsvException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow
    {
        super(msg, file, line);
    }
}

/**
 * RFC 4180 reader: comma separator, double-quoted fields that may hold commas,
 * doubled quotes and line breaks, LF or CRLF records, optional UTF-8 BOM.
 * Blank lines are skipped; every record must have as many fields as the first.
 */
private string[][] parseCsv(string text, string name)
{
    if (text.length >= 3 && text[0 .. 3] == "\xEF\xBB\xBF")
        text = text[3 .. $];
    string[][] recs;
    string[] rec;
    char[] buf;
    bool quoted, afterQuote, fieldStart = true;
    size_t line = 1, recLine = 1;

    void fail(string msg)
    {
        throw new CsvException(name ~ ": line " ~ line.to!string ~ ": " ~ msg);
    }

    void endField()
    {
        rec ~= buf.idup;
        buf.length = 0;
        buf.assumeSafeAppend();
        quoted = afterQuote = false;
        fieldStart = true;
    }

    void endRecord()
    {
        if (rec.length == 0 && fieldStart && buf.length == 0 && !afterQuote)
            return; // blank line
        endField();
        if (recs.length && rec.length != recs[0].length)
        {
            line = recLine;
            fail("expected " ~ recs[0].length.to!string ~ " fields, got " ~ rec.length.to!string);
        }
        recs ~= rec;
        rec = null;
    }

    for (size_t i = 0; i < text.length; i++)
    {
        const c = text[i];
        if (quoted)
        {
            if (c == '"')
            {
                if (i + 1 < text.length && text[i + 1] == '"')
                {
                    buf ~= '"';
                    i++;
                }
                else
                {
                    quoted = false;
                    afterQuote = true;
                }
            }
            else
            {
                if (c == '\n')
                    line++;
                buf ~= c;
            }
            continue;
        }
        if (c == ',')
        {
            endField();
            continue;
        }
        if (c == '\r' || c == '\n')
        {
            if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n')
                i++;
            endRecord();
            line++;
            recLine = line;
            continue;
        }
        if (afterQuote)
            fail("extraneous character after a closing quote");
        if (c == '"')
        {
            if (!fieldStart)
                fail("bare quote in an unquoted field");
            quoted = true;
            fieldStart = false;
            continue;
        }
        buf ~= c;
        fieldStart = false;
    }
    if (quoted)
        fail("unterminated quoted field");
    endRecord();
    if (recs.length == 0)
        throw new CsvException(name ~ ": empty");
    return recs;
}

private struct Row
{
    size_t[string] idx;
    string[] rec;
    string file;
    size_t line;

    noreturn fail(string col, string msg)
    {
        throw new CsvException(file ~ ": record " ~ line.to!string ~ ": " ~ col ~ ": " ~ msg);
    }

    string str(string col)
    {
        if (auto p = col in idx)
            return rec[*p];
        fail(col, "missing column");
    }

    T num(T)(string col)
    {
        auto n = opt!T(col);
        if (n.isNull)
            fail(col, "empty");
        return n.get;
    }

    Nullable!T opt(T)(string col)
    {
        auto s = str(col);
        if (s == "")
            return Nullable!T.init;
        try
            return Nullable!T(s.to!T);
        catch (Exception e)
            fail(col, "not a number: " ~ s);
    }

    bool boolean(string col)
    {
        switch (str(col))
        {
        case "true", "TRUE", "True", "1":
            return true;
        case "false", "FALSE", "False", "0":
            return false;
        default:
            fail(col, "not a boolean: " ~ str(col));
        }
    }

    Nullable!Date date(string col)
    {
        auto s = str(col);
        if (s == "")
            return Nullable!Date.init;
        try
            return Nullable!Date(Date.fromISOExtString(s));
        catch (Exception e)
            fail(col, "not a date: " ~ s);
    }

    string[] list(string col, string sep)
    {
        auto s = str(col);
        if (s == "")
            return null;
        return s.split(sep).map!(p => p.strip).array;
    }
}

private void readCsv(string text, string name, scope void delegate(ref Row) fn)
{
    auto recs = parseCsv(text, name);
    size_t[string] idx;
    foreach (i, h; recs[0])
        idx[h] = i;
    foreach (i, rec; recs[1 .. $])
    {
        auto r = Row(idx, rec, name, i + 2);
        fn(r);
    }
}

private Dataset* load()
{
    auto d = new Dataset;
    readCsv(summaryCsv, "country_summary.csv", (ref Row r) {
        d.countries ~= CountrySummary(
            r.str("iso"), r.str("country"), r.str("region"), r.str("currency"),
            r.num!int("example_salary_usd"), r.str("example_role"), r.str("example_place"),
            r.opt!double("basic_share_of_gross"),
            r.num!double("employer_cost_pct"), r.num!double("employer_cost_pct_printed"),
            r.boolean("total_declared_floor"), r.boolean("total_declared_ceiling"),
            r.num!double("employer_cost_usd_month"), r.str("total_excludes"),
            r.num!double("fx_local_per_usd"), r.date("fx_date"), r.date("last_reviewed"));
    });
    d.countries.sort!((a, b) => a.iso < b.iso);

    readCsv(contributionsCsv, "country_contributions.csv", (ref Row r) {
        auto c = Contribution(
            r.str("iso"), r.str("country"), r.str("currency"), r.str("line_type"),
            r.str("line_id"), r.str("line_name"), r.opt!double("rate"), r.str("base"),
            r.opt!double("base_factor"), r.opt!double("base_floor_annual_local"),
            r.opt!double("base_cap_annual_local"), r.opt!double("flat_annual_local"),
            r.opt!double("min_gross_annual_local"), r.opt!double("max_gross_annual_local"),
            r.str("extra_kind"), r.opt!double("extra_value"),
            r.boolean("secondary_source"), r.boolean("thirteenth_month"),
            r.boolean("total_declared_floor"), r.boolean("total_declared_ceiling"),
            r.boolean("in_total"), r.str("applies"), r.str("notes"),
            r.str("source_name"), r.str("source_url"), r.date("source_checked_at"));
        d.contributions[c.iso] ~= c;
    });

    readCsv(assumptionsCsv, "country_assumptions.csv", (ref Row r) {
        auto a = Assumption(r.str("iso"), r.str("id"), r.str("label"),
            r.num!double("value"), r.str("notes"));
        d.assumptions[a.iso] ~= a;
    });

    return d;
}

// --- tests ---

version (unittest)
{
    private bool isIso(string s, size_t n)
    {
        import std.ascii : isUpper;
        import std.algorithm : all;

        return s.length == n && s.all!isUpper;
    }

    // Records in a CSV text counted independently of parseCsv: line breaks
    // outside quotes, minus the header.
    private size_t countRecords(string text)
    {
        size_t n;
        bool inQ;
        foreach (c; text)
        {
            if (c == '"')
                inQ = !inQ;
            else if (c == '\n' && !inQ)
                n++;
        }
        if (text.length && text[$ - 1] != '\n')
            n++;
        return n - 1;
    }
}

// The parser: quotes, commas, doubled quotes, line breaks, CRLF, BOM, blank lines.
unittest
{
    import std.exception : assertThrown;

    auto r = parseCsv("\xEF\xBB\xBFa,b,c\r\n\"x, y\",\"say \"\"hi\"\"\",\"l1\nl2\"\r\n\n,,\"\"\n1,2,3", "t");
    assert(r == [["a", "b", "c"], ["x, y", `say "hi"`, "l1\nl2"], ["", "", ""], ["1", "2", "3"]]);
    assertThrown!CsvException(parseCsv("a,b\n1\n", "t"));
    assertThrown!CsvException(parseCsv("a\n\"x\"y\n", "t"));
    assertThrown!CsvException(parseCsv("a\nx\"y\n", "t"));
    assertThrown!CsvException(parseCsv("a\n\"open\n", "t"));
}

// 76 countries, valid codes, case-insensitive lookup.
unittest
{
    auto cs = countries();
    assert(cs.length == 76);
    assert(cs.length == countRecords(summaryCsv));
    bool[string] seen;
    foreach (c; cs)
    {
        assert(isIso(c.iso, 2) && c.iso !in seen, c.iso);
        seen[c.iso] = true;
        assert(c.name.length && c.region.length && isIso(c.currency, 3), c.iso);
        assert(c.exampleSalaryUSD > 0 && c.fxLocalPerUSD > 0 && c.employerCostPct >= 0
                && c.employerCostUSDMonth >= 0, c.iso);
        assert(!c.lastReviewed.isNull, c.iso);
        assert(c.currency == "USD" || !c.fxDate.isNull, c.iso);
        if (!c.basicShareOfGross.isNull)
            assert(c.basicShareOfGross.get > 0 && c.basicShareOfGross.get <= 1, c.iso);
        assert(country(c.iso).get.iso == c.iso);
    }
    assert(country("xx").isNull);
    assert(country("de").get.iso == "DE");
}

// Mexico as printed on eorscope.com.
unittest
{
    assert(country("MX").get.employerCostPctPrinted == 30.9);
}

// Five countries drawn at random equal their row of country_summary.csv,
// split here without parseCsv (the file has no quoted field).
unittest
{
    import std.random : randomSample, Random, unpredictableSeed;
    import std.string : lineSplitter;

    assert(!summaryCsv.canFind('"'));
    auto lines = summaryCsv.lineSplitter.filter!(l => l.length).array;
    auto head = lines[0].split(",");
    auto rnd = Random(unpredictableSeed);
    foreach (line; randomSample(lines[1 .. $], 5, rnd))
    {
        auto f = line.split(",");
        assert(f.length == head.length, line);
        string[string] v;
        foreach (i, h; head)
            v[h] = f[i];
        auto c = country(v["iso"]).get;
        string opt(Nullable!double x) { return x.isNull ? "" : x.get.to!string; }
        string day(Nullable!Date x) { return x.isNull ? "" : x.get.toISOExtString; }
        string num(string s) { return s == "" ? "" : s.to!double.to!string; }
        assert(c.name == v["country"] && c.region == v["region"] && c.currency == v["currency"], line);
        assert(c.exampleSalaryUSD == v["example_salary_usd"].to!int, line);
        assert(c.exampleRole == v["example_role"] && c.examplePlace == v["example_place"], line);
        assert(opt(c.basicShareOfGross) == num(v["basic_share_of_gross"]), line);
        assert(c.employerCostPct == v["employer_cost_pct"].to!double, line);
        assert(c.employerCostPctPrinted == v["employer_cost_pct_printed"].to!double, line);
        assert(c.totalDeclaredFloor == (v["total_declared_floor"] == "true"), line);
        assert(c.totalDeclaredCeiling == (v["total_declared_ceiling"] == "true"), line);
        assert(c.employerCostUSDMonth == v["employer_cost_usd_month"].to!double, line);
        assert(c.totalExcludes == v["total_excludes"], line);
        assert(c.fxLocalPerUSD == v["fx_local_per_usd"].to!double, line);
        assert(day(c.fxDate) == v["fx_date"] && day(c.lastReviewed) == v["last_reviewed"], line);
    }
}

// Floor countries: an "at least" figure, flagged on the country and its lines.
unittest
{
    import std.algorithm : count;

    auto ae = country("AE").get;
    assert(ae.totalDeclaredFloor && !ae.totalDeclaredCeiling);
    foreach (l; contributions("AE"))
        assert(l.totalDeclaredFloor);
    assert(!country("DE").get.totalDeclaredFloor);
    assert(countries().count!(c => c.totalDeclaredFloor) == 13);
}

// Regions cover every country once.
unittest
{
    size_t n;
    foreach (r; regions())
    {
        auto cs = countriesInRegion(r);
        assert(cs.length, r);
        foreach (c; cs)
            assert(c.region == r);
        n += cs.length;
    }
    assert(n == countries().length);
}

// Contribution lines, base factors (Mexico's integrated base).
unittest
{
    size_t total;
    size_t[double] factored;
    foreach (c; countries())
    {
        auto lines = contributions(c.iso);
        assert(lines.length, c.iso);
        total += lines.length;
        foreach (l; lines)
        {
            assert(l.iso == c.iso && l.currency == c.currency && l.country == c.name, l.lineID);
            assert(l.totalDeclaredFloor == c.totalDeclaredFloor
                    && l.totalDeclaredCeiling == c.totalDeclaredCeiling, l.lineID);
            switch (l.lineType)
            {
            case "contribution":
                assert(["gross", "basic", "flat", "band"].canFind(l.base) && l.extraKind == "", l.lineID);
                assert((l.base == "flat") == l.baseFactor.isNull, l.lineID);
                if (!l.baseFactor.isNull && l.baseFactor.get != 1)
                    factored[l.baseFactor.get]++;
                break;
            case "statutory_extra":
                assert(["percent", "months", "days"].canFind(l.extraKind) && !l.extraValue.isNull
                        && l.rate.isNull && l.baseFactor.isNull, l.lineID);
                break;
            default:
                assert(0, l.lineType);
            }
            assert(l.lineID.length && l.sourceURL.length && !l.sourceCheckedAt.isNull, l.lineID);
        }
    }
    assert(total == 544);
    assert(total == countRecords(contributionsCsv));
    assert(factored.length == 4 && factored[1.049315] == 9 && factored[1.049867] == 1
            && factored[1.08] == 4 && factored[1.009] == 7);
    assert(contributions("xx").length == 0);
    assert(contributions("mx").length == contributions("MX").length);
}

// Assumptions.
unittest
{
    size_t total;
    foreach (c; countries())
        foreach (a; assumptions(c.iso))
        {
            assert(a.iso == c.iso && a.id.length && a.label.length, c.iso);
            total++;
        }
    assert(total == 108);
}
