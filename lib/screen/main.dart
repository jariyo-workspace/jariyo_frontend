import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jariyo_frontend/core/core.dart';
import 'package:jariyo_frontend/main.dart';
import 'package:jariyo_frontend/screen/home.dart';
import 'package:jariyo_frontend/screen/my_page.dart';
import 'package:jariyo_frontend/screen/reservation.dart';
import 'package:jariyo_frontend/screen/search.dart';
import 'package:jariyo_frontend/screen/sign_in.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: Core.currentIndex,
        children: [
          HomeScreen(),
          SearchScreen(),
          Scaffold(),
          ReservationScreen(),
          MyPageScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: textColor.withAlpha(10))),
        ),
        child: Theme(
          data: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            type: .fixed,
            currentIndex: Core.currentIndex,
            onTap: (value) {
              if (value == 2) {
                Navigator.of(context).push(move(ReservationScreen()));
                return;
              }
              Core.currentIndex = value;
              setState(() {});
            },
            backgroundColor: Colors.white,
            selectedItemColor: primaryColor,
            unselectedItemColor: textColor,
            items: [
              BottomNavigationBarItem(icon: SvgPicture.asset('assets/icons/home.svg', color: Core.currentIndex == 0 ? primaryColor : textColor), label: '홈'),
              BottomNavigationBarItem(icon: SvgPicture.asset('assets/icons/search.svg', color: Core.currentIndex == 1 ? primaryColor : textColor), label: '탐색'),
              BottomNavigationBarItem(icon: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: .circle,
                ),
                alignment: .center,
                child: Icon(Icons.add, color: Colors.white),
              ), label: ''),
              BottomNavigationBarItem(icon: SvgPicture.asset('assets/icons/ticket.svg', color: Core.currentIndex == 3 ? primaryColor : textColor), label: '내 예약'),
              BottomNavigationBarItem(icon: SvgPicture.asset('assets/icons/person.svg', color: Core.currentIndex == 4 ? primaryColor : textColor), label: '마이페이지'),
            ],
          ),
        ),
      ),
    );
  }
}
