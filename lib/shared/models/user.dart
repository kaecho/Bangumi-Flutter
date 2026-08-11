/// 用户信息 (bgm.tv API 结构)
class User {
  final int id;
  final String url;
  final String username;
  final String nickname;
  final UserAvatar avatar;
  final String sign;
  final int userGroup; // 0=游客 1=管理员 2=风纪委员 3=会员 4=维基人 ...

  const User({
    this.id = 0,
    this.url = '',
    this.username = '',
    this.nickname = '',
    this.avatar = const UserAvatar(),
    this.sign = '',
    this.userGroup = 3,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] as num?)?.toInt() ?? 0,
        url: json['url'] as String? ?? '',
        username: json['username'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        avatar: UserAvatar.fromJson(json['avatar'] as Map<String, dynamic>? ?? const {}),
        sign: json['sign'] as String? ?? '',
        userGroup: (json['user_group'] as num?)?.toInt() ?? 3,
      );

  /// 展示名: 昵称优先
  String get displayName => nickname.isNotEmpty ? nickname : username;

  /// 头像地址, 优先大图
  String get avatarUrl => avatar.large.isNotEmpty ? avatar.large : avatar.medium;
}

class UserAvatar {
  final String large;
  final String medium;
  final String small;

  const UserAvatar({this.large = '', this.medium = '', this.small = ''});

  factory UserAvatar.fromJson(Map<String, dynamic> json) => UserAvatar(
        large: json['large'] as String? ?? '',
        medium: json['medium'] as String? ?? '',
        small: json['small'] as String? ?? '',
      );
}

/// 用户组文案
const userGroupText = {
  0: '游客',
  1: '管理员',
  2: '风纪委员',
  3: '会员',
  4: '维基人',
  5: '目录君',
  8: 'QQ菌',
  9: '天窗菌',
  10: '基佬',
  11: '管理员',
  12: '黑暗路人',
  13: '新用户',
  14: '没过验证的用户',
};
