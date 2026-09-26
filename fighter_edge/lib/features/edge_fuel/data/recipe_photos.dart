/// Photos for the recipe catalog, keyed by recipe id.
///
/// Every photo is openly licensed (CC BY or public domain), found through
/// Openverse, checked by eye against its recipe, and resized to WebP; nothing
/// else was changed. Retrieved 2026-09-26. CC BY requires the credit, so a
/// photo without an entry here is never shown. See
/// docs/PRODUCT_PLAN_20260924.md > "Owner decisions (2026-09-26)".
class RecipePhoto {
  const RecipePhoto({
    required this.recipeId,
    required this.author,
    required this.license,
    required this.sourceUrl,
  });

  final String recipeId;
  final String author;

  /// "CC BY 2.0" or "Public domain".
  final String license;

  /// The photo's own page, which also names its licence.
  final String sourceUrl;

  String get assetPath => 'assets/images/recipes/$recipeId.webp';

  /// The visible credit line.
  String get credit => '$author · $license';
}

RecipePhoto? recipePhotoFor(String recipeId) => recipePhotos[recipeId];

const recipePhotos = <String, RecipePhoto>{
  'three-egg-veg-scramble': RecipePhoto(
    recipeId: 'three-egg-veg-scramble',
    author: 'Stacy Spensley',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/21001756@N06/3464755994',
  ),
  'overnight-oats-banana-peanut': RecipePhoto(
    recipeId: 'overnight-oats-banana-peanut',
    author: 'ella.o',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/155807330@N05/30863438117',
  ),
  'greek-yogurt-berry-bowl': RecipePhoto(
    recipeId: 'greek-yogurt-berry-bowl',
    author: 'Average Jane',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/64401168@N00/3604928038',
  ),
  'protein-oat-pancakes': RecipePhoto(
    recipeId: 'protein-oat-pancakes',
    author: 'Stacy Spensley',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/21001756@N06/4334573247',
  ),
  'date-rice-cake-snack': RecipePhoto(
    recipeId: 'date-rice-cake-snack',
    author: 'Double Bean',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/8102985@N05/7428491122',
  ),
  'wholemeal-toast-honey': RecipePhoto(
    recipeId: 'wholemeal-toast-honey',
    author: 'Think YUM!',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/30320107@N06/6613098381',
  ),
  'tunisian-chickpea-bread-bowl': RecipePhoto(
    recipeId: 'tunisian-chickpea-bread-bowl',
    author: 'Phil and Pam',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/33987777@N00/2397457458',
  ),
  'spiced-chicken-rice-bowl': RecipePhoto(
    recipeId: 'spiced-chicken-rice-bowl',
    author: 'kawanet',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/50902562@N00/2597505789',
  ),
  'tuna-white-bean-salad': RecipePhoto(
    recipeId: 'tuna-white-bean-salad',
    author: 'jules:stonesoup',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/58367355@N00/10585910504',
  ),
  'turkey-quinoa-salad': RecipePhoto(
    recipeId: 'turkey-quinoa-salad',
    author: 'comicpie',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/90678392@N00/4158566695',
  ),
  'hummus-veg-wrap': RecipePhoto(
    recipeId: 'hummus-veg-wrap',
    author: 'moriza',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/44373968@N00/174312158',
  ),
  'red-lentil-veg-stew': RecipePhoto(
    recipeId: 'red-lentil-veg-stew',
    author: 'whitneyinchicago',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/29298849@N05/5215904693',
  ),
  'beef-steak-veg-plate': RecipePhoto(
    recipeId: 'beef-steak-veg-plate',
    author: 'jeffreyw',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/7927684@N03/7331360786',
  ),
  'salmon-quinoa-greens': RecipePhoto(
    recipeId: 'salmon-quinoa-greens',
    author: 'Annie Mole',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/21309047@N00/6041522909',
  ),
  'shrimp-veg-stirfry': RecipePhoto(
    recipeId: 'shrimp-veg-stirfry',
    author: 'Rusty Clark',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/23206546@N04/22231165550',
  ),
  'lamb-bulgur-plate': RecipePhoto(
    recipeId: 'lamb-bulgur-plate',
    author: 'WordRidden',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/97844767@N00/483132061',
  ),
  'tofu-veg-stirfry': RecipePhoto(
    recipeId: 'tofu-veg-stirfry',
    author: 'Augapfel',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/47038415@N00/216875127',
  ),
  'cod-potato-veg': RecipePhoto(
    recipeId: 'cod-potato-veg',
    author: 'Prayitno',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/34128007@N04/15988408872',
  ),
  'labneh-cucumber-olive-bowl': RecipePhoto(
    recipeId: 'labneh-cucumber-olive-bowl',
    author: 'T.Tseng',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/68147320@N02/14597127398',
  ),
  'cottage-cheese-fruit-bowl': RecipePhoto(
    recipeId: 'cottage-cheese-fruit-bowl',
    author: 'USDAgov',
    license: 'Public domain',
    sourceUrl: 'https://www.flickr.com/photos/41284017@N08/52644863050',
  ),
  'edamame-quinoa-bowl': RecipePhoto(
    recipeId: 'edamame-quinoa-bowl',
    author: 'Vegan Feast Catering',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/25128194@N02/4326526767',
  ),
  'almond-butter-protein-shake': RecipePhoto(
    recipeId: 'almond-butter-protein-shake',
    author: 'Berries.com',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/126560659@N06/33343287432',
  ),
  'mushroom-spinach-omelette': RecipePhoto(
    recipeId: 'mushroom-spinach-omelette',
    author: 'Andy Hay',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/29172291@N00/12015275683',
  ),
  'beef-mince-bean-chili': RecipePhoto(
    recipeId: 'beef-mince-bean-chili',
    author: 'lejoe',
    license: 'CC BY 2.0',
    sourceUrl: 'https://www.flickr.com/photos/21458229@N00/5090013026',
  ),
};
