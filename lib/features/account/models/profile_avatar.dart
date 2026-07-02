import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileAvatarOption {
  final IconData icon;
  final Color background;
  final String? label;

  const ProfileAvatarOption({
    required this.icon,
    required this.background,
    this.label,
  });
}

final List<ProfileAvatarOption> profileAvatarOptions = [
  // Featured
  ProfileAvatarOption(icon: MdiIcons.schoolOutline, background: Color(0xFF1565C0), label: 'University'),
  ProfileAvatarOption(icon: MdiIcons.rocket, background: Color(0xFFD32F2F), label: 'Rocket'),
  ProfileAvatarOption(icon: MdiIcons.headCogOutline, background: Color(0xFF607D8B), label: 'Thinker'),
  ProfileAvatarOption(icon: MdiIcons.flask, background: Color(0xFF00ACC1), label: 'Science'),

  // Mammals
  ProfileAvatarOption(icon: PhosphorIcons.dog(), background: Color(0xFF8D6E63), label: 'Dog'),
  ProfileAvatarOption(icon: PhosphorIcons.cat(), background: Color(0xFFFFA726), label: 'Cat'),
  ProfileAvatarOption(icon: MdiIcons.rabbit, background: Color(0xFFCE93D8), label: 'Rabbit'),
  ProfileAvatarOption(icon: PhosphorIcons.horse(), background: Color(0xFF5D4037), label: 'Horse'),
  ProfileAvatarOption(icon: PhosphorIcons.cow(), background: Color(0xFFEEEEEE), label: 'Cow'),
  ProfileAvatarOption(icon: MdiIcons.sheep, background: Color(0xFFF5F5F5), label: 'Sheep'),
  ProfileAvatarOption(icon: MdiIcons.pig, background: Color(0xFFF48FB1), label: 'Pig'),
  ProfileAvatarOption(icon: MdiIcons.panda, background: Color(0xFFEFEBE9), label: 'Panda'),
  ProfileAvatarOption(icon: MdiIcons.koala, background: Color(0xFFB0BEC5), label: 'Koala'),
  ProfileAvatarOption(icon: MdiIcons.kangaroo, background: Color(0xFFA1887F), label: 'Kangaroo'),
  ProfileAvatarOption(icon: MdiIcons.bat, background: Color(0xFF333333), label: 'Bat'),

  // Birds
  ProfileAvatarOption(icon: MdiIcons.owl, background: Color(0xFF795548), label: 'Owl'),

  // Reptiles & Amphibians
  ProfileAvatarOption(icon: MdiIcons.turtle, background: Color(0xFF4CAF50), label: 'Turtle'),
  ProfileAvatarOption(icon: MdiIcons.snake, background: Color(0xFF2E7D32), label: 'Snake'),
  ProfileAvatarOption(icon: Icons.pets, background: Color(0xFF8BC34A), label: 'Frog'),
  ProfileAvatarOption(icon: MdiIcons.bone, background: Color(0xFFB0BEC5), label: 'Dino'),
  ProfileAvatarOption(icon: FontAwesomeIcons.dragon, background: Color(0xFFC62828), label: 'Dragon'),
  
  // Sea Life
  ProfileAvatarOption(icon: PhosphorIcons.fish(), background: Color(0xFF42A5F5), label: 'Fish'),
  ProfileAvatarOption(icon: MdiIcons.shark, background: Color(0xFF455A64), label: 'Shark'),
  ProfileAvatarOption(icon: MdiIcons.dolphin, background: Color(0xFF03A9F4), label: 'Dolphin'),

  // Insects
  ProfileAvatarOption(icon: MdiIcons.bee, background: Color(0xFFFFD600), label: 'Bee'),
  ProfileAvatarOption(icon: MdiIcons.butterfly, background: Color(0xFFBA68C8), label: 'Butterfly'),
  ProfileAvatarOption(icon: MdiIcons.ladybug, background: Color(0xFFEF5350), label: 'Ladybug'),
  ProfileAvatarOption(icon: MdiIcons.spider, background: Color(0xFF212121), label: 'Spider'),
  ProfileAvatarOption(icon: MdiIcons.bug, background: Color(0xFFE91E63), label: 'Bug'),
  ProfileAvatarOption(icon: MdiIcons.web, background: Color(0xFFECEFF1), label: 'Web'),

  // Mythical
  ProfileAvatarOption(icon: MdiIcons.unicorn, background: Color(0xFFF06292), label: 'Unicorn'),
  ProfileAvatarOption(icon: MdiIcons.ghost, background: Color(0xFFF5F5F5), label: 'Ghost'),
  ProfileAvatarOption(icon: MdiIcons.alien, background: Color(0xFF00E676), label: 'Alien'),
  ProfileAvatarOption(icon: MdiIcons.robot, background: Color(0xFF78909C), label: 'Robot'),
  ProfileAvatarOption(icon: MdiIcons.skull, background: Color(0xFFEEEEEE), label: 'Skull'),
  ProfileAvatarOption(icon: MdiIcons.pumpkin, background: Color(0xFFFB8C00), label: 'Pumpkin'),
  ProfileAvatarOption(icon: MdiIcons.clover, background: Color(0xFF43A047), label: 'Clover'),
  ProfileAvatarOption(icon: MdiIcons.diamond, background: Color(0xFF81D4FA), label: 'Diamond'),
  ProfileAvatarOption(icon: MdiIcons.crystalBall, background: Color(0xFF7E57C2), label: 'Crystal'),
  ProfileAvatarOption(icon: MdiIcons.magicStaff, background: Color(0xFF8D6E63), label: 'Staff'),

  // Space
  ProfileAvatarOption(icon: MdiIcons.earth, background: Color(0xFF2196F3), label: 'Earth'),
  ProfileAvatarOption(icon: MdiIcons.moonFull, background: Color(0xFFCFD8DC), label: 'Moon'),
  ProfileAvatarOption(icon: MdiIcons.weatherSunny, background: Color(0xFFFBC02D), label: 'Sun'),
  ProfileAvatarOption(icon: MdiIcons.star, background: Color(0xFFFFC107), label: 'Star'),
  ProfileAvatarOption(icon: MdiIcons.telescope, background: Color(0xFF455A64), label: 'Telescope'),
  ProfileAvatarOption(icon: MdiIcons.ufo, background: Color(0xFFAED581), label: 'UFO'),
  ProfileAvatarOption(icon: MdiIcons.satellite, background: Color(0xFF90A4AE), label: 'Satellite'),
  ProfileAvatarOption(icon: MdiIcons.weatherNight, background: Color(0xFF1A237E), label: 'Night'),
  ProfileAvatarOption(icon: MdiIcons.orbit, background: Color(0xFF3F51B5), label: 'Galaxy'),

  // Hobbies / Life
  ProfileAvatarOption(icon: MdiIcons.palette, background: Color(0xFFEC407A), label: 'Art'),
  ProfileAvatarOption(icon: MdiIcons.camera, background: Color(0xFF424242), label: 'Photo'),
  ProfileAvatarOption(icon: MdiIcons.music, background: Color(0xFF9C27B0), label: 'Music'),
  ProfileAvatarOption(icon: MdiIcons.bookOpenVariant, background: Color(0xFF795548), label: 'Reading'),
  ProfileAvatarOption(icon: MdiIcons.controllerClassic, background: Color(0xFF37474F), label: 'Gaming'),
  ProfileAvatarOption(icon: MdiIcons.bicycle, background: Color(0xFFF4511E), label: 'Bike'),
  ProfileAvatarOption(icon: MdiIcons.laptop, background: Color(0xFF546E7A), label: 'Coding'),
  ProfileAvatarOption(icon: MdiIcons.microphone, background: Color(0xFFD32F2F), label: 'Podcast'),
  ProfileAvatarOption(icon: MdiIcons.movie, background: Color(0xFF000000), label: 'Movie'),
  ProfileAvatarOption(icon: MdiIcons.headphones, background: Color(0xFF1E88E5), label: 'Audio'),

  // Sports
  ProfileAvatarOption(icon: MdiIcons.basketball, background: Color(0xFFE65100), label: 'Basketball'),
  ProfileAvatarOption(icon: MdiIcons.soccer, background: Color(0xFFFFFFFF), label: 'Soccer'),
  ProfileAvatarOption(icon: MdiIcons.football, background: Color(0xFF5D4037), label: 'Football'),
  ProfileAvatarOption(icon: MdiIcons.tennis, background: Color(0xFFC6FF00), label: 'Tennis'),
  ProfileAvatarOption(icon: MdiIcons.baseball, background: Color(0xFFFAFAFA), label: 'Baseball'),
  ProfileAvatarOption(icon: MdiIcons.volleyball, background: Color(0xFFFFF176), label: 'Volleyball'),
  ProfileAvatarOption(icon: MdiIcons.dumbbell, background: Color(0xFF263238), label: 'Gym'),
  ProfileAvatarOption(icon: MdiIcons.medal, background: Color(0xFFFFC107), label: 'Medal'),
  ProfileAvatarOption(icon: MdiIcons.trophy, background: Color(0xFFFFB300), label: 'Winner'),
  ProfileAvatarOption(icon: MdiIcons.swim, background: Color(0xFF0288D1), label: 'Swim'),

  // Nature / Plants
  ProfileAvatarOption(icon: MdiIcons.flower, background: Color(0xFFF06292), label: 'Flower'),
  ProfileAvatarOption(icon: MdiIcons.tree, background: Color(0xFF388E3C), label: 'Tree'),
  ProfileAvatarOption(icon: MdiIcons.cactus, background: Color(0xFF2E7D32), label: 'Cactus'),
  ProfileAvatarOption(icon: MdiIcons.leaf, background: Color(0xFF8BC34A), label: 'Leaf'),
  ProfileAvatarOption(icon: MdiIcons.mushroom, background: Color(0xFFE53935), label: 'Mushroom'),
  ProfileAvatarOption(icon: MdiIcons.pineTree, background: Color(0xFF1B5E20), label: 'Pine'),
  ProfileAvatarOption(icon: MdiIcons.sprout, background: Color(0xFF00C853), label: 'Sprout'),
  ProfileAvatarOption(icon: MdiIcons.corn, background: Color(0xFFFFEB3B), label: 'Corn'),
  ProfileAvatarOption(icon: MdiIcons.carrot, background: Color(0xFFFB8C00), label: 'Carrot'),
  ProfileAvatarOption(icon: MdiIcons.chiliHot, background: Color(0xFFD32F2F), label: 'Chili'),

  // Symbols
  ProfileAvatarOption(icon: PhosphorIcons.heart(), background: Color(0xFFE91E63), label: 'Heart'),
  ProfileAvatarOption(icon: PhosphorIcons.lightning(), background: Color(0xFFFFD600), label: 'Bolt'),
  ProfileAvatarOption(icon: PhosphorIcons.fire(), background: Color(0xFFFF6F00), label: 'Fire'),
  ProfileAvatarOption(icon: PhosphorIcons.drop(), background: Color(0xFF2196F3), label: 'Water'),
  ProfileAvatarOption(icon: PhosphorIcons.wind(), background: Color(0xFF90A4AE), label: 'Wind'),
  ProfileAvatarOption(icon: PhosphorIcons.snowflake(), background: Color(0xFFB2EBF2), label: 'Snow'),
  ProfileAvatarOption(icon: PhosphorIcons.compass(), background: Color(0xFF795548), label: 'Compass'),
  ProfileAvatarOption(icon: PhosphorIcons.anchor(), background: Color(0xFF1A237E), label: 'Anchor'),
  ProfileAvatarOption(icon: PhosphorIcons.key(), background: Color(0xFFFFB300), label: 'Key'),
  ProfileAvatarOption(icon: PhosphorIcons.shield(), background: Color(0xFF1565C0), label: 'Shield'),
  ProfileAvatarOption(icon: PhosphorIcons.crown(), background: Color(0xFFFFC107), label: 'Crown'),
  ProfileAvatarOption(icon: PhosphorIcons.lightbulb(), background: Color(0xFFFFD54F), label: 'Idea'),

  // Fun & Silly
  ProfileAvatarOption(icon: MdiIcons.pizza, background: Color(0xFFFB8C00), label: 'Pizza'),
  ProfileAvatarOption(icon: MdiIcons.cupcake, background: Color(0xFFF48FB1), label: 'Cupcake'),
  ProfileAvatarOption(icon: MdiIcons.iceCream, background: Color(0xFFF8BBD0), label: 'Ice Cream'),
  ProfileAvatarOption(icon: MdiIcons.popcorn, background: Color(0xFFFFF176), label: 'Popcorn'),
  ProfileAvatarOption(icon: MdiIcons.coffee, background: Color(0xFF4E342E), label: 'Coffee'),
  ProfileAvatarOption(icon: MdiIcons.tea, background: Color(0xFF558B2F), label: 'Tea'),
  ProfileAvatarOption(icon: MdiIcons.cake, background: Color(0xFFEF9A9A), label: 'Cake'),
  ProfileAvatarOption(icon: MdiIcons.cookie, background: Color(0xFFD7CCC8), label: 'Cookie'),
  ProfileAvatarOption(icon: MdiIcons.candyOutline, background: Color(0xFFD81B60), label: 'Candy'),
  ProfileAvatarOption(icon: MdiIcons.emoticonCool, background: Color(0xFF42A5F5), label: 'Cool'),
  ProfileAvatarOption(icon: MdiIcons.emoticonExcited, background: Color(0xFFFFB300), label: 'Excited'),
  ProfileAvatarOption(icon: MdiIcons.emoticonHappy, background: Color(0xFFFFA726), label: 'Happy'),
  ProfileAvatarOption(icon: MdiIcons.emoticonWink, background: Color(0xFF9C27B0), label: 'Wink'),
  ProfileAvatarOption(icon: MdiIcons.emoticonTongue, background: Color(0xFFE53935), label: 'Silly'),
  ProfileAvatarOption(icon: MdiIcons.balloon, background: Color(0xFF4FC3F7), label: 'Balloon'),
  ProfileAvatarOption(icon: MdiIcons.partyPopper, background: Color(0xFFFFD600), label: 'Party'),
  ProfileAvatarOption(icon: MdiIcons.sunglasses, background: Color(0xFF212121), label: 'Sunglasses'),
  ProfileAvatarOption(icon: MdiIcons.mustache, background: Color(0xFF5D4037), label: 'Mustache'),
  ProfileAvatarOption(icon: MdiIcons.bowTie, background: Color(0xFF1565C0), label: 'Bow Tie'),
  ProfileAvatarOption(icon: MdiIcons.hatFedora, background: Color(0xFF616161), label: 'Fedora'),
  
  // More Fun Stuff
  ProfileAvatarOption(icon: MdiIcons.rodent, background: Color(0xFFFFCC80), label: 'Hamster'),
  ProfileAvatarOption(icon: MdiIcons.tortoise, background: Color(0xFF689F38), label: 'Tortoise'),
  ProfileAvatarOption(icon: MdiIcons.fishbowl, background: Color(0xFF80DEEA), label: 'Fishbowl'),
  ProfileAvatarOption(icon: MdiIcons.penguin, background: Color(0xFF263238), label: 'Penguin'),
  ProfileAvatarOption(icon: MdiIcons.food, background: Color(0xFFF06292), label: 'Donut'),
  ProfileAvatarOption(icon: MdiIcons.hamburger, background: Color(0xFF795548), label: 'Burger'),
  ProfileAvatarOption(icon: MdiIcons.noodles, background: Color(0xFFFFF59D), label: 'Noodles'),
  ProfileAvatarOption(icon: MdiIcons.food, background: Color(0xFFE57373), label: 'Sushi'),
  ProfileAvatarOption(icon: MdiIcons.baguette, background: Color(0xFFD7CCC8), label: 'Baguette'),
  ProfileAvatarOption(icon: MdiIcons.dice6, background: Color(0xFFC62828), label: 'Dice'),
  ProfileAvatarOption(icon: MdiIcons.treasureChest, background: Color(0xFFFFD700), label: 'Treasure'),
  ProfileAvatarOption(icon: MdiIcons.wizardHat, background: Color(0xFF3F51B5), label: 'Wizard'),
  ProfileAvatarOption(icon: MdiIcons.guitarAcoustic, background: Color(0xFF8D6E63), label: 'Guitar'),
  ProfileAvatarOption(icon: MdiIcons.violin, background: Color(0xFF5D4037), label: 'Violin'),
  ProfileAvatarOption(icon: MdiIcons.piano, background: Color(0xFF212121), label: 'Piano'),
  ProfileAvatarOption(icon: MdiIcons.trumpet, background: Color(0xFFFFD600), label: 'Trumpet'),
  ProfileAvatarOption(icon: MdiIcons.magnet, background: Color(0xFFC62828), label: 'Magnet'),
  ProfileAvatarOption(icon: MdiIcons.bomb, background: Color(0xFF37474F), label: 'Bomb'),
  ProfileAvatarOption(icon: MdiIcons.giftOutline, background: Color(0xFFE91E63), label: 'Gift'),
];

Color profileAvatarForeground(ProfileAvatarOption option) {
  final brightness = ThemeData.estimateBrightnessForColor(option.background);
  return brightness == Brightness.dark ? Colors.white : Colors.black87;
}

ProfileAvatarOption? profileAvatarOptionFor(int? index) {
  if (index == null || index < 0 || index >= profileAvatarOptions.length) {
    return null;
  }
  return profileAvatarOptions[index];
}
