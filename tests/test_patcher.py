import struct
import unittest

import patcher


class PatchEncodingTests(unittest.TestCase):
    def test_branch_reaches_code_cave(self):
        self.assertEqual(patcher.PATCHED_BRANCH.hex(" "), "e9 99 15 00 00")
        displacement = struct.unpack("<i", patcher.PATCHED_BRANCH[1:])[0]
        self.assertEqual(patcher.BRANCH_VA + 5 + displacement, patcher.CAVE_VA)

    def test_cave_is_position_independent_and_returns(self):
        self.assertEqual(
            patcher.PATCHED_CAVE.hex(" "),
            "e8 00 00 00 00 58 05 6f 83 07 00 6a 01 ff 10 e9 26 eb ff ff",
        )
        self.assertEqual(len(patcher.PATCHED_CAVE), 20)
        iat_delta = struct.unpack("<i", patcher.PATCHED_CAVE[7:11])[0]
        self.assertEqual(patcher.CAVE_VA + 5 + iat_delta, patcher.SLEEP_IAT_VA)
        return_delta = struct.unpack("<i", patcher.PATCHED_CAVE[16:20])[0]
        self.assertEqual(
            patcher.CAVE_VA + len(patcher.PATCHED_CAVE) + return_delta,
            patcher.ORIGINAL_CONTINUE_VA,
        )


if __name__ == "__main__":
    unittest.main()
