import '../../features/profile/domain/user_identity_profile.dart';

/// Shared identity preservation instructions for image generation.
class IdentityConsistencyPrompt {
  IdentityConsistencyPrompt._();

  static const String seed = '''
IDENTITY CONSISTENCY (mandatory):
- same person
- same facial identity
- same skin tone
- same body proportions
- same hairstyle
''';

  static String preserveFromProfiles({
    AiFaceProfile? face,
    AiBodyProfile? body,
  }) {
    final lines = <String>['Preserve exactly:'];
    if (face != null && !face.isEmpty) {
      if (face.skinTone != null) lines.add('- ${face.skinTone} skin tone');
      if (face.faceShape != null) {
        lines.add('- ${face.faceShape} facial structure');
      }
      if (face.hairColor != null || face.hairStyle != null) {
        final hair = [
          face.hairColor,
          face.hairStyle,
        ].whereType<String>().join(' ');
        lines.add('- $hair hair');
      }
      if (face.eyeShape != null) lines.add('- ${face.eyeShape} eyes');
    }
    if (body != null && !body.isEmpty) {
      if (body.bodyType != null) lines.add('- ${body.bodyType} body type');
      if (body.build != null) lines.add('- ${body.build} build');
      if (body.heightEstimate != null) {
        lines.add('- ${body.heightEstimate} height proportion');
      }
      if (body.shoulderWidth != null) {
        lines.add('- ${body.shoulderWidth} shoulders');
      }
    }
    if (lines.length <= 1) return '';
    return lines.join('\n');
  }

  static String buildBlock({
    AiFaceProfile? face,
    AiBodyProfile? body,
  }) {
    final preserve = preserveFromProfiles(face: face, body: body);
    if (preserve.isEmpty) return seed;
    return '$seed\n$preserve';
  }
}
