/*
 * Copyright (C) 2013 Soheil Damangir - All Rights Reserved
 * You may use and distribute, but not modify this code under the terms of the
 * Creative Commons Attribution-NonCommercial-NoDerivs 3.0 Unported License
 * under the following conditions:
 *
 * Attribution — You must attribute the work in the manner specified by the
 * author or licensor (but not in any way that suggests that they endorse you
 * or your use of the work).
 * Noncommercial — You may not use this work for commercial purposes.
 * No Derivative Works — You may not alter, transform, or build upon this
 * work
 *
 * To view a copy of the license, visit
 * http://creativecommons.org/licenses/by-nc-nd/3.0/
 */

/* RN:
 * Robust masked outlier
 * default mean and covariance
 */
#define CASCADE_VERSION "0.3"

/* RN:
 * init mask to WM or WM+GM
 * Outlier layer
 */
// #define CASCADE_VERSION "0.2"

/* RN:
 * Basic implementation:
 * Filters
 * Outlier
 * Masked-statistics
 */
// #define CASCADE_VERSION "0.1"

#ifndef DIM
#define DIM 3
#endif
#define SLICEDIM (DIM-1)
#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)
#define DIMSTR STR(DIM)
#define BUILDINFO "(built at " __DATE__ " " __TIME__ " for " DIMSTR " dimensional input image)"
#pragma message ("Build info:" BUILDINFO)
