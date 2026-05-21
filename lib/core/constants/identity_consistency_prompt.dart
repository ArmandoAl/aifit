import '../../features/profile/domain/user_identity_profile.dart';

/// Identity preservation blocks for base image and try-on generation.
class IdentityConsistencyPrompt {
  IdentityConsistencyPrompt._();

  static const String seed = '''
IDENTITY CONSISTENCY (mandatory):
- same person
- same facial identity
- same skin tone
- same ethnicity
- same body proportions
- same hairstyle
''';

  static const String tryOnReinforcement = '''
IDENTITY PRESERVATION (highest priority):
Identity preservation is MORE important than artistic stylization.

- Preserve exact skin tone. Do not lighten skin tone.
- Preserve ethnicity. Do not alter ethnicity.
- Preserve facial proportions and bone structure.
- Preserve hairstyle, hair color, and hair density.
- Preserve body type, shoulder width, and build.
- The generated person must look like the SAME individual.

Do NOT apply beauty retouching, skin lightening, or ethnic alteration.
''';

  static const String baseImageStyle = '''
VISUAL STYLE:
- Neutral, clean, realistic, premium ecommerce catalog look
- Even soft studio lighting — NOT cinematic or dramatic
- No editorial fashion styling, no heavy retouching, no stylization
''';

  static String preserveFromProfile(IdentityProfile? profile) {
    if (profile == null || profile.isEmpty) return '';

    final lines = <String>['Preserve exactly:'];

    final skin = profile.skinTone;
    if (skin?.primary != null) {
      lines.add('- ${skin!.primary} skin tone');
      if (skin.undertone != null) lines.add('- ${skin.undertone} undertone');
    }

    final face = profile.face;
    if (face?.shape != null) {
      lines.add('- ${face!.shape} face shape');
    }
    if (face?.jawDefinition != null) {
      lines.add('- ${face!.jawDefinition} jaw');
    }
    if (face?.eyeShape != null) lines.add('- ${face!.eyeShape} eyes');

    final hair = profile.hair;
    if (hair?.color != null || hair?.style != null) {
      final h = [hair?.color, hair?.style].whereType<String>().join(' ');
      lines.add('- $h hair');
    }

    final body = profile.body;
    if (body?.type != null) lines.add('- ${body!.type} body type');
    if (body?.build != null) lines.add('- ${body!.build} build');
    if (body?.heightEstimate != null) {
      lines.add('- ${body!.heightEstimate} height');
    }
    if (body?.shoulderWidth != null) {
      lines.add('- ${body!.shoulderWidth} shoulders');
    }

    return lines.length > 1 ? lines.join('\n') : '';
  }

  static String buildBlock({IdentityProfile? profile, bool forTryOn = false}) {
    final parts = <String>[seed];
    if (forTryOn) parts.add(tryOnReinforcement);
    final preserve = preserveFromProfile(profile);
    if (preserve.isNotEmpty) parts.add(preserve);
    return parts.join('\n\n');
  }

  static String buildBaseImageBlock(IdentityProfile? profile) {
    return '${buildBlock(profile: profile)}\n\n$baseImageStyle';
  }

  static String buildTryOnBlock(IdentityProfile? profile) {
    return buildBlock(profile: profile, forTryOn: true);
  }
}
