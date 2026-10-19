namespace RecipeRaccoon.DensityApi.Application.Seeding;

/// What recipes in the app's other languages (Dutch, German, French, Spanish) call the
/// <see cref="UsdaSeedData"/> ingredients. The app matches a recipe's ingredient name against
/// the density table strictly, so without these a Dutch "2 el bloem" never finds "all-purpose
/// flour" and shows "Conversion not available".
///
/// Each translated name becomes a seed row of its own with the English row's FDC source and
/// density, the same way "flour" repeats "all-purpose flour". No density is new here.
///
/// Only names that mean the same product as the English row are listed, lower case like the
/// English names. Where the usual product differs from the US one, the name is left out rather
/// than guessed: European mustard isn't yellow mustard, "Trockenhefe" and "gedroogde gist" are
/// usually instant yeast, and there's no half-and-half. A name equal to the English one
/// ("ketchup", German "butter") or used in two languages (French and Spanish "miel") becomes
/// one row.
public static class TranslatedSeedNames
{
    public sealed record Translation(string EnglishName, string[] Dutch, string[] German, string[] French, string[] Spanish)
    {
        public IEnumerable<string> Names => [.. Dutch, .. German, .. French, .. Spanish];
    }

    public static IReadOnlyList<Translation> Translations { get; } =
    [
        // Flours, grains and starches
        new("all-purpose flour",
            Dutch: ["bloem", "tarwebloem", "patentbloem"],
            German: ["mehl", "weizenmehl"],
            French: ["farine", "farine de blé"],
            Spanish: ["harina", "harina de trigo"]),
        new("bread flour", Dutch: [], German: [], French: ["farine de force"], Spanish: ["harina de fuerza"]),
        new("whole wheat flour",
            Dutch: ["volkorenmeel", "volkoren tarwemeel"],
            German: ["vollkornmehl", "weizenvollkornmehl"],
            French: ["farine complète"],
            Spanish: ["harina integral", "harina de trigo integral"]),
        new("self-rising flour",
            Dutch: ["zelfrijzend bakmeel", "zelfrijzend meel"],
            German: [],
            French: ["farine à levure incorporée"],
            Spanish: ["harina leudante"]),
        new("cornstarch",
            Dutch: ["maizena", "maïzena", "maïszetmeel"],
            German: ["maisstärke"],
            French: ["maïzena", "maizena", "fécule de maïs"],
            Spanish: ["maicena", "fécula de maíz", "almidón de maíz"]),
        new("rolled oats",
            Dutch: ["havermout"],
            German: ["haferflocken"],
            French: ["flocons d'avoine"],
            Spanish: ["copos de avena", "avena en hojuelas"]),
        new("white rice",
            Dutch: ["witte rijst"],
            German: ["weißer reis", "langkornreis"],
            French: ["riz blanc", "riz long"],
            Spanish: ["arroz blanco", "arroz de grano largo"]),
        new("quinoa", Dutch: [], German: [], French: [], Spanish: ["quinua"]),
        new("breadcrumbs",
            Dutch: ["paneermeel"],
            German: ["semmelbrösel", "paniermehl"],
            French: ["chapelure"],
            Spanish: ["pan rallado"]),

        // Sugars and syrups. French "sucre en poudre" is left out: granulated sugar in France,
        // but powdered sugar in Belgium, Canada and Switzerland (120 vs 200 g a cup).
        new("granulated sugar",
            Dutch: ["suiker", "kristalsuiker", "witte suiker"],
            German: ["zucker", "weißer zucker", "kristallzucker"],
            French: ["sucre", "sucre blanc", "sucre semoule"],
            Spanish: ["azúcar", "azúcar blanco", "azúcar blanca", "azúcar granulado"]),
        new("brown sugar",
            Dutch: ["bruine suiker"],
            German: ["brauner zucker"],
            French: ["sucre brun"],
            Spanish: ["azúcar moreno", "azúcar morena"]),
        new("powdered sugar",
            Dutch: ["poedersuiker"],
            German: ["puderzucker"],
            French: ["sucre glace"],
            Spanish: ["azúcar glas", "azúcar glass", "azúcar impalpable"]),
        new("honey", Dutch: ["honing"], German: ["honig"], French: ["miel"], Spanish: ["miel"]),
        new("maple syrup",
            Dutch: ["ahornsiroop"],
            German: ["ahornsirup"],
            French: ["sirop d'érable"],
            Spanish: ["sirope de arce", "jarabe de arce"]),
        new("molasses", Dutch: ["melasse"], German: ["melasse"], French: ["mélasse"], Spanish: ["melaza"]),
        new("corn syrup", Dutch: [], German: ["maissirup"], French: ["sirop de maïs"], Spanish: ["jarabe de maíz"]),

        // Fats and oils. The butter row is unsalted butter. Spanish "manteca" is left out: it's
        // lard in Spain and butter in Argentina.
        new("butter",
            Dutch: ["boter", "roomboter", "ongezouten roomboter", "ongezouten boter"],
            German: ["ungesalzene butter"],
            French: ["beurre", "beurre doux"],
            Spanish: ["mantequilla", "mantequilla sin sal"]),
        new("vegetable oil",
            Dutch: ["plantaardige olie"],
            German: ["pflanzenöl"],
            French: ["huile végétale"],
            Spanish: ["aceite vegetal"]),
        new("olive oil", Dutch: ["olijfolie"], German: ["olivenöl"], French: ["huile d'olive"], Spanish: ["aceite de oliva"]),
        new("canola oil",
            Dutch: ["koolzaadolie"],
            German: ["rapsöl"],
            French: ["huile de colza"],
            Spanish: ["aceite de canola", "aceite de colza"]),
        new("coconut oil",
            Dutch: ["kokosolie"],
            German: ["kokosöl"],
            French: ["huile de coco", "huile de noix de coco"],
            Spanish: ["aceite de coco"]),
        new("sesame oil", Dutch: ["sesamolie"], German: ["sesamöl"], French: ["huile de sésame"], Spanish: ["aceite de sésamo"]),
        new("lard", Dutch: ["reuzel"], German: ["schweineschmalz", "schmalz"], French: ["saindoux"], Spanish: ["manteca de cerdo"]),

        // Dairy. The milk row is whole milk, the yogurt row whole-milk plain yogurt.
        new("milk",
            Dutch: ["melk", "volle melk"],
            German: ["milch", "vollmilch"],
            French: ["lait", "lait entier"],
            Spanish: ["leche", "leche entera"]),
        new("buttermilk",
            Dutch: ["karnemelk"],
            German: ["buttermilch"],
            French: ["babeurre", "lait ribot"],
            Spanish: ["suero de mantequilla"]),
        new("heavy cream",
            Dutch: ["slagroom"],
            German: ["schlagsahne"],
            French: ["crème fleurette", "crème liquide entière", "crème entière liquide"],
            Spanish: ["nata para montar", "crema para batir"]),
        new("sour cream",
            Dutch: ["zure room"],
            German: ["saure sahne", "sauerrahm"],
            French: ["crème aigre"],
            Spanish: ["crema agria", "nata agria"]),
        new("plain yogurt",
            Dutch: ["volle yoghurt", "yoghurt naturel"],
            German: ["naturjoghurt"],
            French: ["yaourt nature"],
            Spanish: ["yogur natural"]),
        new("cream cheese",
            Dutch: ["roomkaas"],
            German: ["frischkäse"],
            French: ["fromage à la crème"],
            Spanish: ["queso crema", "queso para untar"]),
        new("grated parmesan",
            Dutch: ["geraspte parmezaanse kaas", "geraspte parmezaan"],
            German: ["geriebener parmesan"],
            French: ["parmesan râpé"],
            Spanish: ["queso parmesano rallado", "parmesano rallado"]),
        new("shredded cheddar",
            Dutch: ["geraspte cheddar"],
            German: ["geriebener cheddar"],
            French: ["cheddar râpé"],
            Spanish: ["queso cheddar rallado", "cheddar rallado"]),
        new("shredded mozzarella",
            Dutch: ["geraspte mozzarella"],
            German: ["geriebener mozzarella"],
            French: ["mozzarella râpée"],
            Spanish: ["mozzarella rallada", "queso mozzarella rallado"]),

        // Leaveners, spices and flavorings. A recipe measures cinnamon, nutmeg and pepper by
        // the spoon only when ground, so the plain names count as the ground rows.
        new("salt", Dutch: ["zout", "fijn zout"], German: ["salz"], French: ["sel", "sel fin"], Spanish: ["sal", "sal fina"]),
        new("baking soda",
            Dutch: ["zuiveringszout", "natriumbicarbonaat"],
            German: ["natron"],
            French: ["bicarbonate de soude", "bicarbonate alimentaire"],
            Spanish: ["bicarbonato de sodio", "bicarbonato sódico"]),
        new("baking powder",
            Dutch: ["bakpoeder"],
            German: ["backpulver"],
            French: ["levure chimique", "poudre à lever"],
            Spanish: ["polvo de hornear", "polvo para hornear", "levadura química"]),
        new("cream of tartar", Dutch: ["cremor tartari"], German: ["weinstein"], French: ["crème de tartre"], Spanish: ["cremor tártaro"]),
        new("cocoa powder",
            Dutch: ["cacaopoeder"],
            German: ["kakaopulver"],
            French: ["cacao en poudre", "cacao non sucré"],
            Spanish: ["cacao en polvo", "cacao puro"]),
        new("ground cinnamon",
            Dutch: ["kaneel", "gemalen kaneel", "kaneelpoeder"],
            German: ["zimt", "gemahlener zimt"],
            French: ["cannelle", "cannelle moulue", "cannelle en poudre"],
            Spanish: ["canela", "canela molida", "canela en polvo"]),
        new("ground ginger",
            Dutch: ["gemberpoeder", "gemalen gember"],
            German: ["ingwerpulver", "gemahlener ingwer"],
            French: ["gingembre moulu", "gingembre en poudre"],
            Spanish: ["jengibre molido", "jengibre en polvo"]),
        new("ground nutmeg",
            Dutch: ["nootmuskaat", "gemalen nootmuskaat"],
            German: ["muskatnuss", "gemahlene muskatnuss"],
            French: ["noix de muscade", "muscade", "noix de muscade moulue"],
            Spanish: ["nuez moscada", "nuez moscada molida"]),
        new("black pepper",
            Dutch: ["zwarte peper", "gemalen zwarte peper"],
            German: ["schwarzer pfeffer", "gemahlener schwarzer pfeffer"],
            French: ["poivre noir", "poivre noir moulu"],
            Spanish: ["pimienta negra", "pimienta negra molida"]),
        new("paprika", Dutch: ["paprikapoeder"], German: ["paprikapulver"], French: [], Spanish: ["pimentón", "pimentón dulce"]),
        new("garlic powder", Dutch: ["knoflookpoeder"], German: ["knoblauchpulver"], French: ["ail en poudre"], Spanish: ["ajo en polvo"]),
        new("onion powder", Dutch: ["uienpoeder"], German: ["zwiebelpulver"], French: ["oignon en poudre"], Spanish: ["cebolla en polvo"]),
        new("vanilla extract",
            Dutch: ["vanille-extract", "vanilleextract"],
            German: ["vanilleextrakt"],
            French: ["extrait de vanille"],
            Spanish: ["extracto de vainilla"]),

        // Liquids and condiments
        new("water", Dutch: [], German: ["wasser"], French: ["eau"], Spanish: ["agua"]),
        new("lemon juice",
            Dutch: ["citroensap"],
            German: ["zitronensaft"],
            French: ["jus de citron"],
            Spanish: ["jugo de limón", "zumo de limón"]),
        new("lime juice",
            Dutch: ["limoensap"],
            German: ["limettensaft"],
            French: ["jus de citron vert"],
            Spanish: ["jugo de lima", "zumo de lima"]),
        new("soy sauce",
            Dutch: ["sojasaus"],
            German: ["sojasauce", "sojasoße"],
            French: ["sauce soja"],
            Spanish: ["salsa de soja", "salsa de soya"]),
        new("white vinegar", Dutch: ["witte azijn"], German: ["weißer essig"], French: ["vinaigre blanc"], Spanish: ["vinagre blanco"]),
        new("apple cider vinegar",
            Dutch: ["appelciderazijn", "appelazijn"],
            German: ["apfelessig"],
            French: ["vinaigre de cidre"],
            Spanish: ["vinagre de manzana", "vinagre de sidra"]),
        new("balsamic vinegar",
            Dutch: ["balsamicoazijn", "balsamico azijn"],
            German: ["balsamicoessig", "balsamico"],
            French: ["vinaigre balsamique"],
            Spanish: ["vinagre balsámico"]),
        new("red wine vinegar",
            Dutch: ["rodewijnazijn", "rode wijnazijn"],
            German: ["rotweinessig"],
            French: ["vinaigre de vin rouge"],
            Spanish: ["vinagre de vino tinto"]),
        new("mayonnaise", Dutch: ["mayonaise"], German: [], French: [], Spanish: ["mayonesa"]),
        new("ketchup", Dutch: ["tomatenketchup"], German: ["tomatenketchup"], French: [], Spanish: []),
        new("coconut milk", Dutch: ["kokosmelk"], German: ["kokosmilch"], French: ["lait de coco"], Spanish: ["leche de coco"]),
        new("peanut butter",
            Dutch: ["pindakaas"],
            German: ["erdnussbutter"],
            French: ["beurre de cacahuète", "beurre de cacahuètes", "beurre d'arachide"],
            Spanish: ["mantequilla de cacahuete", "mantequilla de maní", "crema de cacahuete"]),

        // Mix-ins, nuts and seeds. The walnut and pecan rows are chopped, the almond row sliced.
        new("chocolate chips",
            Dutch: ["chocoladedruppels"],
            German: ["schokotropfen", "schokoladentropfen"],
            French: ["pépites de chocolat"],
            Spanish: ["chispas de chocolate", "pepitas de chocolate"]),
        new("raisins", Dutch: ["rozijnen"], German: ["rosinen"], French: ["raisins secs"], Spanish: ["pasas", "uvas pasas"]),
        new("walnuts",
            Dutch: ["walnoten", "gehakte walnoten"],
            German: ["walnüsse", "walnusskerne", "gehackte walnüsse"],
            French: ["noix", "cerneaux de noix", "noix hachées"],
            Spanish: ["nueces", "nueces picadas"]),
        new("pecans",
            Dutch: ["pecannoten"],
            German: ["pekannüsse"],
            French: ["noix de pécan"],
            Spanish: ["nueces pecanas", "nueces pecán", "pacanas"]),
        new("sliced almonds",
            Dutch: ["amandelschaafsel", "geschaafde amandelen"],
            German: ["mandelblättchen"],
            French: ["amandes effilées"],
            Spanish: ["almendras laminadas", "almendras fileteadas"]),
        new("shredded coconut", Dutch: ["kokosrasp"], German: ["kokosraspeln"], French: ["noix de coco râpée"], Spanish: ["coco rallado"]),
        new("sesame seeds",
            Dutch: ["sesamzaad"],
            German: ["sesam", "sesamsamen"],
            French: ["graines de sésame"],
            Spanish: ["semillas de sésamo", "ajonjolí"]),
    ];

    /// One row per distinct translated name. French sites print either apostrophe ("huile d'olive",
    /// "huile d’olive"), and the app compares names exactly, so a name with either gets a row for
    /// each spelling.
    public static IReadOnlyList<DensitySeedRow> Rows { get; } = BuildRows();

    private static List<DensitySeedRow> BuildRows()
    {
        var english = UsdaSeedData.Rows.ToDictionary(row => row.IngredientName);
        return Translations
            .SelectMany(translation => translation.Names
                .SelectMany(ApostropheSpellings)
                .Distinct()
                .Where(name => name != translation.EnglishName)
                .Select(name => english[translation.EnglishName] with { IngredientName = name }))
            .ToList();
    }

    private static string[] ApostropheSpellings(string name) =>
        name.Contains('\'') || name.Contains('’') ? [name.Replace('’', '\''), name.Replace('\'', '’')] : [name];
}
